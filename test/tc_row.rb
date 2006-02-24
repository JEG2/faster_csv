#!/usr/local/bin/ruby -w

# tc_row.rb
#
#  Created by James Edward Gray II on 2006-02-24.
#  Copyright 2006 Gray Productions. All rights reserved.

require "test/unit"

require "faster_csv/row"

class TestFasterCSVRow < Test::Unit::TestCase
  def setup
    @row = FasterCSV::Row.new(%w{A B C A A}, [1, 2, 3, 4])
  end
  
  def test_initialize
    # basic
    row = FasterCSV::Row.new(%w{A B C}, [1, 2, 3])
    assert_not_nil(row)
    assert_instance_of(FasterCSV::Row, row)
    assert_equal([["A", 1], ["B", 2], ["C", 3]], row.to_a)
    
    # missing headers
    row = FasterCSV::Row.new(%w{A}, [1, 2, 3])
    assert_not_nil(row)
    assert_instance_of(FasterCSV::Row, row)
    assert_equal([["A", 1], [nil, 2], [nil, 3]], row.to_a)
    
    # missing fields
    row = FasterCSV::Row.new(%w{A B C}, [1, 2])
    assert_not_nil(row)
    assert_instance_of(FasterCSV::Row, row)
    assert_equal([["A", 1], ["B", 2], ["C", nil]], row.to_a)
  end
  
  def test_headers
    assert_equal(%w{A B C A A}, @row.headers)
  end
  
  def test_field
    # by name
    assert_equal(2, @row.field("B"))

    # by index
    assert_equal(3, @row.field(2))
    
    # missing
    assert_nil(@row.field("Missing"))
    assert_nil(@row.field(10))
    
    # minimum index
    assert_equal(1, @row.field("A"))
    assert_equal(1, @row.field("A", 0))
    assert_equal(4, @row.field("A", 1))
    assert_equal(4, @row.field("A", 2))
    assert_equal(4, @row.field("A", 3))
    assert_equal(nil, @row.field("A", 4))
    assert_equal(nil, @row.field("A", 5))
  end
  
  def test_fields
    # all fields
    assert_equal([1, 2, 3, 4, nil], @row.fields)
    
    # by header
    assert_equal([1, 3], @row.fields("A", "C"))
    
    # by index
    assert_equal([2, 3, nil], @row.fields(1, 2, 10))
    
    # by both
    assert_equal([2, 3, 4], @row.fields("B", "C", 3))
    
    # with minimum indices
    assert_equal([2, 3, 4], @row.fields("B", "C", ["A", 3]))
  end
  
  def test_index
    # basic usage
    assert_equal(0, @row.index("A"))
    assert_equal(1, @row.index("B"))
    assert_equal(2, @row.index("C"))
    assert_equal(nil, @row.index("Z"))

    # with minimum index
    assert_equal(0, @row.index("A"))
    assert_equal(0, @row.index("A", 0))
    assert_equal(3, @row.index("A", 1))
    assert_equal(3, @row.index("A", 2))
    assert_equal(3, @row.index("A", 3))
    assert_equal(4, @row.index("A", 4))
    assert_equal(nil, @row.index("A", 5))
  end
  
  def test_queries
    # headers
    assert(@row.header?("A"))
    assert(@row.header?("C"))
    assert(!@row.header?("Z"))
    assert(@row.include?("A"))
    
    # fields
    assert(@row.field?(4))
    assert(@row.field?(nil))
    assert(!@row.field?(10))
  end
  
  def test_each
    # array style
    ary = @row.to_a
    @row.each do |pair|
      assert_equal(ary.first.first, pair.first)
      assert_equal(ary.shift.last, pair.last)
    end
    
    # hash style
    ary = @row.to_a
    @row.each do |header, field|
      assert_equal(ary.first.first, header)
      assert_equal(ary.shift.last, field)
    end
  end
  
  def test_enumerable
    assert_equal( [["A", 1], ["A", 4], ["A", nil]],
                  @row.select { |pair| pair.first == "A" } )
    
    assert_equal(10, @row.inject(0) { |sum, (header, n)| sum + (n || 0) })
  end
  
  def test_to_a
    row = FasterCSV::Row.new(%w{A B C}, [1, 2, 3]).to_a
    assert_instance_of(Array, row)
    row.each do |pair|
      assert_instance_of(Array, pair)
      assert_equal(2, pair.size)
    end
    assert_equal([["A", 1], ["B", 2], ["C", 3]], row)
  end
  
  def test_to_hash
    assert_equal({"A" => nil, "B" => 2, "C" => 3}, @row.to_hash)
  end
end
