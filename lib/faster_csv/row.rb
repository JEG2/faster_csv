#!/usr/local/bin/ruby -w

# row.rb
#
#  Created by James Edward Gray II on 2006-02-24.
#  Copyright 2006 Gray Productions. All rights reserved.

class FasterCSV
  class Row
    include Enumerable
    
    def initialize( headers, fields )
      @row = if headers.size > fields.size
        headers.zip(fields)
      else
        fields.zip(headers).map { |pair| pair.reverse }
      end
    end
    
    def headers
      @row.map { |pair| pair.first }
    end
    
    def field( header_or_index, minimum_index = 0 )
      finder = header_or_index.is_a?(Integer) ? :[] : :assoc
      pair   = @row[minimum_index..-1].send(finder, header_or_index)

      pair.nil? ? nil : pair.last
    end
    
    def fields( *headers_and_or_indices )
      if headers_and_or_indices.empty?
        @row.map { |pair| pair.last }
      else
        headers_and_or_indices.map { |h_or_i| field(*Array(h_or_i)) }
      end
    end
    
    def index( header, minimum_index = 0 )
      index = headers[minimum_index..-1].index(header)
      index.nil? ? nil : index + minimum_index
    end
    
    def header?( name )
      headers.include? name
    end
    alias_method :include?, :header?
    
    def field?( data )
      fields.include? data
    end
    
    def each( &block )
      @row.each(&block)
    end
    
    def to_hash
      Hash[*@row.inject(Array.new) { |ary, pair| ary.push(*pair) }]
    end
  end
end
