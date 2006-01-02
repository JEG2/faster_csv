#!/usr/local/bin/ruby -w

# = faster_csv.rb -- Faster CSV Reading and Writing
#
#  Created by James Edward Gray II on 2005-10-31.
#  Copyright 2005 Gray Productions. All rights reserved.
# 
# See FasterCSV for documentation.

require "stringio"
require "forwardable"
require "enumerator"
require "date"

# 
# This class provides a complete interface to CSV files and data.  It offers
# tools to enable you to read and write to and from Strings or IO objects, as
# needed.
# 
# == Reading
# 
# === From a File
# 
# ==== A Line at a Time
# 
#   FasterCSV.foreach("path/to/file.csv") do |row|
#     # use row here...
#   end
# 
# ==== All at Once
# 
#   arr_of_arrs = FasterCSV.read("path/to/file.csv")
# 
# === From a String
# 
# ==== A Line at a Time
# 
#   FasterCSV.parse("CSV,data,String") do |row|
#     # use row here...
#   end
# 
# ==== All at Once
# 
#   arr_of_arrs = FasterCSV.parse("CSV,data,String")
# 
# == Writing
# 
# === To a File
# 
#   FasterCSV.open("path/to/file.csv", "w") do |csv|
#     csv << ["row", "of", "CSV", "data"]
#     csv << ["another", "row"]
#     # ...
#   end
# 
# === To a String
# 
#   csv_string = FasterCSV.generate do |csv|
#     csv << ["row", "of", "CSV", "data"]
#     csv << ["another", "row"]
#     # ...
#   end
# 
# == Convert a Single Line
# 
#   csv_string = ["CSV", "data"].to_csv   # to CSV
#   csv_array  = "CSV,String".parse_csv   # from CSV
# 
class FasterCSV
  # The error thrown when the parser encounters illegal CSV formatting.
  class MalformedCSVError < RuntimeError; end
  
  # 
  # A FieldInfo Struct contains details about a field's position in the data
  # source it was read from.  FasterCSV will pass this Struct to some blocks
  # that make decisions based on field structure.  See 
  # FasterCSV.convert_fields() for an example.
  # 
  # <b><tt>index</tt></b>::  The zero-based index of the field in its row.
  # <b><tt>line</tt></b>::   The line of the data source this row is from.
  # 
  FieldInfo = Struct.new(:index, :line)
  
  # 
  # This Hash holds the built-in converters of FasterCSV that can be accessed by
  # name.  You can select Converters with FasterCSV.convert() or through the
  # +options+ Hash passed to FasterCSV::new().
  # 
  # <b><tt>:integer</tt></b>::    Converts any field Integer() accepts.
  # <b><tt>:float</tt></b>::      Converts any field Float() accepts.
  # <b><tt>:numeric</tt></b>::    A combination of <tt>:integer</tt> 
  #                               and <tt>:float</tt>.
  # <b><tt>:date</tt></b>::       Converts any field Date::parse() accepts.
  # <b><tt>:date_time</tt></b>::  Converts any field DateTime::parse() accepts.
  # <b><tt>:all</tt></b>::        All built-in converters.  A combination of 
  #                               <tt>:date_time</tt> and <tt>:numeric</tt>.
  # 
  # This Hash is intetionally left unfrozen and users should feel free to add
  # values to it that can be accessed by all FasterCSV objects.
  # 
  # To add a combo field, the value should be an Array of names.  Combo fields
  # can be nested with other combo fields.
  # 
  Converters = { :integer   => lambda { |f| Integer(f)        rescue f },
                 :float     => lambda { |f| Float(f)          rescue f },
                 :numeric   => [:integer, :float],
                 :date      => lambda { |f| Date.parse(f)     rescue f },
                 :date_time => lambda { |f| DateTime.parse(f) rescue f },
                 :all       => [:date_time, :numeric] }
  
  # 
  # The options used when no overrides are given by calling code.  They are:
  # 
  # <b><tt>:col_sep</tt></b>::     <tt>","</tt>
  # <b><tt>:row_sep</tt></b>::     <tt>:auto</tt>
  # <b><tt>:converters</tt></b>::  <tt>nil</tt>
  # 
  DEFAULT_OPTIONS = {:col_sep => ",", :row_sep => :auto, :converters => nil}
  
  # 
  # :call-seq:
  #   filter( options = Hash.new ) { |row| ... }
  #   filter( input, options = Hash.new ) { |row| ... }
  #   filter( input, output, options = Hash.new ) { |row| ... }
  # 
  # This method is a convenience for building Unix-like filters for CSV data.
  # Each row is yielded to the provided block which can alter it as needed.  
  # After the block returns, the row is appended to _output_ altered or not.
  # 
  # The _input_ and _output_ arguments can be anything FasterCSV::new() accepts
  # (generally String or IO objects).  If not given, they default to 
  # <tt>$stdin</tt> and <tt>$stdout</tt>.
  # 
  # The _options_ parameter is also filtered down to FasterCSV::new() after some
  # clever key parsing.  Any key beginning with <tt>:in_</tt> or 
  # <tt>:input_</tt> will have that leading identifier stripped and will only
  # be used in the _options_ Hash for the _input_ object.  Keys starting with
  # <tt>:out_</tt> or <tt>:output_</tt> affect only _output_.  All other keys 
  # are assigned to both objects.
  # 
  def self.filter( *args )
    # parse options for input, output, or both
    input_options, output_options = Hash.new, Hash.new
    if args.last.is_a? Hash
      args.pop.each do |key, value|
        case key.to_s
        when /\Ain(?:put)?_(.+)\Z/
          input_options[$1.to_sym] = value
        when /\Aout(?:put)?_(.+)\Z/
          output_options[$1.to_sym] = value
        else
          input_options[key]  = value
          output_options[key] = value
        end
      end
    end
    # build input and output wrappers
    input   = FasterCSV.new(args.shift || $stdin,  input_options)
    output  = FasterCSV.new(args.shift || $stdout, output_options)
    
    # read, yield, write
    input.each do |row|
      yield row
      output << row
    end
  end
  
  # 
  # This method is intended as the primary interface for reading CSV files.  You
  # pass a +path+ and any +options+ you wish to set for the read.  Each row of
  # file will be passed to the provided +block+ in turn.
  # 
  # The +options+ parameter can be anthing FasterCSV::new() understands.
  # 
  def self.foreach( path, options = Hash.new, &block )
    open(path, options) do |csv|
      csv.each(&block)
    end
  end

  # 
  # :call-seq:
  #   generate( str, options = Hash.new ) { |faster_csv| ... }
  #   generate( options = Hash.new ) { |faster_csv| ... }
  # 
  # This method wraps a String you provide, or an empty default String, in a 
  # FasterCSV object which is passed to the provided block.  You can use the 
  # block to append CSV rows to the String and when the block exits, the 
  # final String will be returned.
  # 
  # Note that a passed String *is* modfied by this method.  Call dup() before
  # passing if you need a new String.
  # 
  # The +options+ parameter can be anthing FasterCSV::new() understands.
  # 
  def self.generate( *args )
    # add a default empty String, if none was given
    if args.first.is_a? String
      io = StringIO.new(args.shift)
      io.seek(0, IO::SEEK_END)
      args.unshift(io)
    else
      args.unshift("")
    end
    faster_csv = new(*args)  # wrap
    yield faster_csv         # yield for appending
    faster_csv.string        # return final String
  end

  # 
  # This method is a shortcut for converting a single row (Array) into a CSV 
  # String.
  # 
  # The +options+ parameter can be anthing FasterCSV::new() understands.
  # 
  def self.generate_line( row, options = Hash.new )
    (new("", options) << row).string
  end
  
  # 
  # :call-seq:
  #   open( filename, mode="r", options = Hash.new ) { |faster_csv| ... }
  #   open( filename, mode="r", options = Hash.new )
  # 
  # This method opens an IO object, and wraps that with FasterCSV.  This is
  # intended as the primary interface for writing a CSV file.
  # 
  # You may pass any +args+ Ruby's open() understands followed by an optional
  # Hash containing any +options+ FasterCSV::new() understands.
  # 
  # This method works like Ruby's open() call, in that it will pass a FasterCSV
  # object to a provided block and close it when the block termminates, or it
  # will return the FasterCSV object when no block is provided.  (*Note*: This
  # is different from the standard CSV library which passes rows to the block.  
  # Use FasterCSV::foreach() for that behavior.)
  # 
  # An opened FasterCSV object will delegate to many IO methods, for 
  # convenience.  You may call:
  # 
  # * binmode()
  # * close()
  # * close_read()
  # * close_write()
  # * closed?()
  # * eof()
  # * eof?()
  # * fcntl()
  # * fileno()
  # * flush()
  # * fsync()
  # * ioctl()
  # * isatty()
  # * lineno()
  # * pid()
  # * pos()
  # * reopen()
  # * rewind()
  # * seek()
  # * stat()
  # * sync()
  # * sync=()
  # * tell()
  # * to_i()
  # * to_io()
  # * tty?()
  # 
  def self.open( *args )
    # find the +options+ Hash
    options = if args.last.is_a? Hash then args.pop else Hash.new end
    # wrap a File opened with the remaining +args+
    csv     = new(File.open(*args), options)
    
    # handle blocks like Ruby's open(), not like the CSV library
    if block_given?
      begin
        yield csv
      ensure
        csv.close
      end
    else
      csv
    end
  end
  
  # 
  # :call-seq:
  #   parse( str, options = Hash.new ) { |row| ... }
  #   parse( str, options = Hash.new )
  # 
  # This method can be used to easily parse CSV out of a String.  You may either
  # provide a +block+ which will be called with each row of the String in turn,
  # or just use the returned Array of Arrays (when no +block+ is given).
  # 
  # You pass your +str+ to read from, and an optional +options+ Hash containing
  # anything FasterCSV::new() understands.
  # 
  def self.parse( *args, &block )
    csv = new(*args)
    if block.nil?  # slurp contents, if no block is given
      begin
        csv.read
      ensure
        csv.close
      end
    else           # or pass each row to a provided block
      csv.each(&block)
    end
  end
  
  # 
  # This method is a shortcut for converting a single line of a CSV String into 
  # a into an Array.  Note that if +line+ contains multiple rows, anything 
  # beyond the first row is ignored.
  # 
  # The +options+ parameter can be anthing FasterCSV::new() understands.
  # 
  def self.parse_line( line, options = Hash.new )
    new(line, options).shift
  end
  
  # 
  # Use to slurp a CSV file into an Array of Arrays.  Pass the +path+ to the 
  # file and any +options+ FasterCSV::new() understands.
  # 
  def self.read( path, options = Hash.new )
    open(path, options) { |csv| csv.read }
  end
  
  # Alias for FasterCSV::read().
  def self.readlines( *args )
    read(*args)
  end
  
  # 
  # This constructor will wrap either a String or IO object passed in +data+ for
  # reading and/or writing.  In addition to the FasterCSV instance methods, 
  # several IO methods are delegated.  (See FasterCSV::open() for a complete 
  # list.)  If you pass a String for +data+, you can later retrieve it (after
  # writing to it, for example) with FasterCSV.string().
  # 
  # Note that a wrapped String will be positioned at at the beginning (for 
  # reading).  If you want it at the end (for writing), use 
  # FasterCSV::generate().  If you want any other positioning, pass a preset 
  # StringIO object instead.
  # 
  # You may set any reading and/or writing preferences in the +options+ Hash.  
  # Available options are:
  # 
  # <b><tt>:col_sep</tt></b>::     The String placed between each field.
  # <b><tt>:row_sep</tt></b>::     The String appended to the end of each row.
  #                                This can be set to the special <tt>:auto</tt>
  #                                setting, which requests that FasterCSV 
  #                                automatically discover this from the data.
  #                                Auto-discovery reads ahead in the data 
  #                                looking for the next <tt>"\r\n"</tt>, 
  #                                <tt>"\n"</tt>, or <tt>"\r"</tt> sequence.  A
  #                                sequence will be selected even if it occurs
  #                                in a quoted field, assuming that you would
  #                                have the same line endings there.  If none of
  #                                those sequences is found, the default 
  #                                <tt>$/</tt> is used.  Obviously, discovery 
  #                                takes a little time.  Set manually if speed
  #                                is important.
  # <b><tt>:converters</tt></b>::  An Array of names from the Converters Hash
  #                                and/or lambdas that handle custom conversion.
  #                                A single converter doesn't have to be in an
  #                                Array.
  # 
  # See FasterCSV::DEFAULT_OPTIONS for the default settings.
  # 
  # Options cannot be overriden in the instance methods for performance reasons,
  # so be sure to set what you want here.
  # 
  def initialize( data, options = Hash.new )
    # build the options for this read/write
    options = DEFAULT_OPTIONS.merge(options)
    
    # create the IO object we will read from
    @io = if data.is_a? String then StringIO.new(data) else data end
    
    init_separators(options)
    init_parsers(options)
    init_converters(options)
    
    unless options.empty?
      raise ArgumentError, "Unknown options:  #{options.keys.join(', ')}."
    end
  end
  
  ### IO and StringIO Delegation ###
  
  extend Forwardable
  def_delegators :@io, :binmode, :close, :close_read, :close_write, :closed?,
                       :eof, :eof?, :fcntl, :fileno, :flush, :fsync, :ioctl,
                       :isatty, :lineno, :pid, :pos, :reopen, :rewind, :seek,
                       :stat, :string, :sync, :sync=, :tell, :to_i, :to_io,
                       :tty?

  ### End Delegation ###
  
  # 
  # The primary write method for wrapped Strings and IOs, +row+ (an Array) is
  # converted to CSV and appended to the data source.
  # 
  # The data source must be open for writing.
  # 
  def <<( row )
    @io << row.map do |field|
      if field.nil?  # reverse +nil+ fields as empty unquoted fields
        ""
      else
        field = String(field)  # Stringify fields
        # reverse empty fields as empty quoted fields
        if field.empty? or field.count(%Q{\r\n#{@col_sep}"}).nonzero?
          %Q{"#{field.gsub('"', '""')}"}  # escape quoted fields
        else
          field  # unquoted field
        end
      end
    end.join(@col_sep) + @row_sep  # add separators
    
    self  # for chaining
  end
  alias_method :add_row, :<<
  alias_method :puts,    :<<
  
  # 
  # :call-seq:
  #   convert( name )
  #   convert { |field| ... }
  #   convert { |field, field_info| ... }
  # 
  # You can use this method to install a FasterCSV::Converters built-in, or 
  # provide a block that handles a custom conversion.
  # 
  # If you provide a block that takes one argument, it will be passed the field
  # and is expected to return the converted value or the field itself.  If your
  # block takes two arguments, it will also be passed a FieldInfo Struct, 
  # containing details about the field.  Again, the block should return a 
  # converted field or the field itself.
  # 
  def convert( name = nil, &converter )
    if name.nil?  # custom converter
      @converters << converter
    else          # named converter
      combo = FasterCSV::Converters[name]
      case combo
      when Array  # combo converter
        combo.each { |converter_name| convert(converter_name) }
      else        # individual named converter
        @converters << combo
      end
    end
  end
  
  include Enumerable
  
  # 
  # Yields each row of the data source in turn.
  # 
  # Support for Enumerable.
  # 
  # The data source must be open for reading.
  # 
  def each
    while row = shift
      yield row
    end
  end
  
  # 
  # Slurps the remaining rows and returns an Array of Arrays.
  # 
  # The data source must be open for reading.
  # 
  def read
    to_a
  end
  alias_method :readlines, :read
  
  # 
  # The primary read method for wrapped Strings and IOs, a single row is pulled
  # from the data source, parsed and returned as an Array of fields.
  # 
  # The data source must be open for reading.
  # 
  def shift
    # begin with a blank line, so we can always add to it
    line = ""

    # 
    # it can take multiple calls to <tt>@io.gets()</tt> to get a full line,
    # because of \r and/or \n characters embedded in quoted fields
    # 
    loop do
      # add another read to the line
      line  += @io.gets(@row_sep) rescue return nil
      # copy the line so we can chop it up in parsing
      parse = line.dup
      parse.sub!(@parsers[:line_end], "")
      
      # 
      # I believe a blank line should be an <tt>Array.new</tt>, not 
      # CSV's <tt>[nil]</tt>
      # 
      return Array.new if parse.empty?

      # 
      # shave leading empty fields if needed, because the main parser chokes 
      # on these
      # 
      csv = if parse.sub!(@parsers[:leading_fields], "")
        [nil] * $&.length
      else
        Array.new
      end
      # 
      # then parse the main fields with a hyper-tuned Regexp from 
      # Mastering Regular Expressions, Second Edition
      # 
      parse.gsub!(@parsers[:csv_row]) do
        csv << if $1.nil?     # we found an unquoted field
          if $2.empty?        # switch empty unquoted fields to +nil+...
            nil               # for CSV compatibility
          else
            # I decided to take a strict approach to CSV parsing...
            if $2.count("\r\n").zero?  # verify correctness of field...
              $2
            else
              # or throw an Exception
              raise MalformedCSVError, 'Unquoted fields do not allow \r or \n.'
            end
          end
        else                  # we found a quoted field...
          $1.gsub('""', '"')  # unescape contents
        end
        ""  # gsub!'s replacement, clear the field
      end

      # if parse is empty?(), we found all the fields on the line...
      if parse.empty?
        if @converters.empty?
          break csv
        else
          break convert_fields(csv)
        end
      end
      # if we're not empty?() but at eof?(), a quoted field wasn't closed...
      raise MalformedCSVError, "Unclosed quoted field." if @io.eof?
      # otherwise, we need to loop and pull some more data to complete the row
    end
  end
  alias_method :gets,     :shift
  alias_method :readline, :shift
  
  private
  
  # 
  # Stores the indicated separators for later use.
  # 
  # If auto-discovery was requested for <tt>@row_sep</tt>, this method will read
  # ahead in the <tt>@io</tt> and try to find one.
  # 
  def init_separators( options )
    # store the selected separators
    @col_sep = options.delete(:col_sep)
    @row_sep = options.delete(:row_sep)
    
    # automatically discover row separator when requested
    saved_pos = @io.pos  # remember where we were
    while @row_sep == :auto
      # 
      # if we run out of data, it's probably a single line 
      # (use a sensible default)
      # 
      if @io.eof?
        @row_sep = $/
        break
      end
      
      # read ahead a bit
      sample =  @io.read(1024)
      sample += @io.read(1) if sample[-1..-1] == "\r" and not @io.eof?
      
      # try to find a standard separator
      if sample =~ /\r\n?|\n/
        @row_sep = $&
        break
      end
    end
    @io.seek(saved_pos)  # reset back to the remembered position 
  end
  
  # Pre-compiles parsers and stores them by name for access during reads.
  def init_parsers( options )
    # prebuild Regexps for faster parsing
    @parsers    = {
      :leading_fields =>
        /\A#{Regexp.escape(@col_sep)}+/,         # for empty leading fields
      :csv_row        =>
        ### The Primary Parser ###
        / \G(?:^|#{Regexp.escape(@col_sep)})     # anchor the match
          (?: "((?>[^"]*)(?>""[^"]*)*)"          # find quoted fields
              |                                  # ... or ...
              ([^"#{Regexp.escape(@col_sep)}]*)  # unquoted fields
              )/x,
        ### End Primary Parser ###
      :line_end       =>
        /#{Regexp.escape(@row_sep)}\Z/           # safer than chomp!()
    }
  end
  
  # Loads any converters requested during construction.
  def init_converters( options )
    @converters = Array.new
    
    # load converters
    unless options[:converters].nil?
      # allow a single converter not wrapped in an Array
      unless options[:converters].is_a? Array
        options[:converters] = [options[:converters]]
      end
      # load each converter...
      options[:converters].each do |converter|
        if converter.is_a? Proc  # custom code block
          convert(&converter)
        else                     # by name
          convert(converter)
        end
      end
    end
    
    options.delete(:converters)
  end
  
  # 
  # Processes +fields+ with <tt>@converters</tt>, returning the converted field
  # set.  Any converter that changes the field into something other than a
  # String halts the pipeline of conversion for that field.  This is primarily
  # an efficiency shortcut.
  # 
  def convert_fields( fields )
    fields.enum_for(:each_with_index).map do |field, index|  # map_with_index
      @converters.each do |converter|
        field = if converter.arity == 1  # straight field converter
          converter[field]
        else                             # FieldInfo converter
          converter[field, FieldInfo.new(index, @io.lineno)]
        end
        break unless field.is_a? String  # short-curcuit pipeline for speed
      end
      field  # return final state of each field, converted or original
    end
  end
end

class Array
  # Equivalent to <tt>FasterCSV::generate_line(self, options)</tt>.
  def to_csv( options = Hash.new )
    FasterCSV.generate_line(self, options)
  end
end

class String
  # Equivalent to <tt>FasterCSV::parse_line(self, options)</tt>.
  def parse_csv( options = Hash.new )
    FasterCSV.parse_line(self, options)
  end
end
