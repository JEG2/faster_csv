#!/usr/local/bin/ruby -w

# tc_features.rb
#
#  Created by James Edward Gray II on 2005-11-14.
#  Copyright 2005 Gray Productions. All rights reserved.

require "test/unit"

require "faster_csv"

class TestFasterCSVFeatures < Test::Unit::TestCase
  TEST_CASES = [ [%Q{a,b},               ["a", "b"]],
                 [%Q{a,"""b"""},         ["a", "\"b\""]],
                 [%Q{a,"""b"},           ["a", "\"b"]],
                 [%Q{a,"b"""},           ["a", "b\""]],
                 [%Q{a,"\nb"""},         ["a", "\nb\""]],
                 [%Q{a,"""\nb"},         ["a", "\"\nb"]],
                 [%Q{a,"""\nb\n"""},     ["a", "\"\nb\n\""]],
                 [%Q{a,"""\nb\n""",\nc}, ["a", "\"\nb\n\"", nil]],
                 [%Q{a,,,},              ["a", nil, nil, nil]],
                 [%Q{,},                 [nil, nil]],
                 [%Q{"",""},             ["", ""]],
                 [%Q{""""},              ["\""]],
                 [%Q{"""",""},           ["\"",""]],
                 [%Q{,""},               [nil,""]],
                 [%Q{,"\r"},             [nil,"\r"]],
                 [%Q{"\r\n,"},           ["\r\n,"]],
                 [%Q{"\r\n,",},          ["\r\n,", nil]] ]
  
  def setup
    @sample_data = <<-END_DATA.gsub(/^ +/, "")
    line,1,abc
    line,2,"def\nghi"
    
    line,4,jkl
    END_DATA
    @csv = FasterCSV.new(@sample_data)
  end
  
  def test_col_sep
    [";", "\t"].each do |sep|
      TEST_CASES.each do |test_case|
        assert_equal( test_case.last.map { |t| t.tr(",", sep) unless t.nil? },
                      FasterCSV.parse_line( test_case.first.tr(",", sep),
                                            :col_sep => sep ) )
      end
    end
    assert_equal( [",,,", nil],
                  FasterCSV.parse_line(",,,;", :col_sep => ";") )
  end
  
  def test_row_sep
    assert_raise(FasterCSV::MalformedCSVError) do
        FasterCSV.parse_line("1,2,3\n,4,5\r\n", :row_sep => "\r\n")
    end
    assert_equal( ["1", "2", "3\n", "4", "5"],
                  FasterCSV.parse_line( %Q{1,2,"3\n",4,5\r\n},
                                        :row_sep => "\r\n") )
  end
  
  def test_row_sep_auto_discovery
    ["\r\n", "\n", "\r"].each do |line_end|
      data       = "1,2,3#{line_end}4,5#{line_end}"
      discovered = FasterCSV.new(data).instance_eval { @row_sep }
      assert_equal(line_end, discovered)
    end
    
    assert_equal("\n", FasterCSV.new("\n\r\n\r").instance_eval { @row_sep })
    
    assert_equal($/, FasterCSV.new("").instance_eval { @row_sep })
    
    assert_equal($/, FasterCSV.new(STDERR).instance_eval { @row_sep })
  end
  
  def test_lineno
    assert_equal(5, @sample_data.to_a.size)
    
    4.times do |line_count|
      assert_equal(line_count, @csv.lineno)
      assert_not_nil(@csv.shift)
      assert_equal(line_count + 1, @csv.lineno)
    end
    assert_nil(@csv.shift)
  end
  
  def test_readline
    test_lineno
    
    @csv.rewind
    
    test_lineno
  end
  
  def test_unknown_options
    assert_raise(ArgumentError) do 
      FasterCSV.new(String.new, :unknown => :error)
    end
  end
  
  def test_skip_blanks
    assert_equal(4, @csv.to_a.size)

    @csv  = FasterCSV.new(@sample_data, :skip_blanks => true)
    
    count = 0
    @csv.each do |row|
      count += 1
      assert_equal("line", row.first)
    end
    assert_equal(3, count)
  end
  
  # reported by Kev Jackson
  def test_failing_to_escape_col_sep_bug_fix
    assert_nothing_raised(Exception) do 
      FasterCSV.new(String.new, :col_sep => "|")
    end
  end
  
  # reported by Chris Roos
  def test_failing_to_reset_headers_in_rewind_bug_fix
    csv = FasterCSV.new( "forename,surname", :headers        => true,
                                             :return_headers => true )
    csv.each { |row| assert row.header_row? }
    csv.rewind
    csv.each { |row| assert row.header_row? }
  end
  
  # reported by Dave Burt
  def test_leading_empty_fields_with_multibyte_col_sep_bug_fix
    data = <<-END_DATA.gsub(/^\s+/, "")
    <=><=>A<=>B<=>C
    1<=>2<=>3
    END_DATA
    parsed = FasterCSV.parse(data, :col_sep => "<=>")
    assert_equal([[nil, nil, "A", "B", "C"], ["1", "2", "3"]], parsed)
  end
  
  def test_version
    assert_not_nil(FasterCSV::VERSION)
    assert_instance_of(String, FasterCSV::VERSION)
    assert(FasterCSV::VERSION.frozen?)
    assert_match(/\A\d\.\d\.\d\Z/, FasterCSV::VERSION)
  end
end
