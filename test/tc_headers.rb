#!/usr/local/bin/ruby -w

# tc_headers.rb
#
#  Created by James Edward Gray II on 2006-02-25.
#  Copyright 2006 Gray Productions. All rights reserved.

require "test/unit"

require "faster_csv"

class TestFasterCSVHeaders < Test::Unit::TestCase
  def setup
    @data = <<-END_CSV.gsub(/^\s+/, "")
    first,second,third
    A,B,C
    1,2,3
    END_CSV
  end
  
  def test_first_row
    [:first_row, true].each do |setting|  # two names for the same setting
      # activate headers
      csv = nil
      assert_nothing_raised(Exception) do 
        csv = FasterCSV.parse(@data, :headers => setting)
      end

      # first data row - skipping headers
      row = csv.shift
      assert_not_nil(row)
      assert_instance_of(FasterCSV::Row, row)
      assert_equal([%w{first A}, %w{second B}, %w{third C}], row.to_a)

      # second data row
      row = csv.shift
      assert_not_nil(row)
      assert_instance_of(FasterCSV::Row, row)
      assert_equal([%w{first 1}, %w{second 2}, %w{third 3}], row.to_a)

      # empty
      assert_nil(csv.shift)
    end
  end
  
  def test_array_of_headers
    # activate headers
    csv = nil
    assert_nothing_raised(Exception) do 
      csv = FasterCSV.parse(@data, :headers => [:my, :new, :headers])
    end

    # first data row - skipping headers
    row = csv.shift
    assert_not_nil(row)
    assert_instance_of(FasterCSV::Row, row)
    assert_equal( [[:my, "first"], [:new, "second"], [:headers, "third"]],
                  row.to_a )

    # second data row
    row = csv.shift
    assert_not_nil(row)
    assert_instance_of(FasterCSV::Row, row)
    assert_equal([[:my, "A"], [:new, "B"], [:headers, "C"]], row.to_a)

    # third data row
    row = csv.shift
    assert_not_nil(row)
    assert_instance_of(FasterCSV::Row, row)
    assert_equal([[:my, "1"], [:new, "2"], [:headers, "3"]], row.to_a)

    # empty
    assert_nil(csv.shift)
    
    # with return and convert
    assert_nothing_raised(Exception) do
      csv = FasterCSV.parse(@data, :headers           => [:my, :new, :headers],
                                   :return_headers    => true,
                                   :header_converters => lambda { |h| h.to_s } )
    end
    row = csv.shift
    assert_not_nil(row)
    assert_instance_of(FasterCSV::Row, row)
    assert_equal( [["my", :my], ["new", :new], ["headers", :headers]],
                  row.to_a )
    assert(row.header_row?)
    assert(!row.field_row?)
  end
  
  def test_csv_header_string
    # activate headers
    csv = nil
    assert_nothing_raised(Exception) do 
      csv = FasterCSV.parse(@data, :headers => "my,new,headers")
    end

    # first data row - skipping headers
    row = csv.shift
    assert_not_nil(row)
    assert_instance_of(FasterCSV::Row, row)
    assert_equal([%w{my first}, %w{new second}, %w{headers third}], row.to_a)

    # second data row
    row = csv.shift
    assert_not_nil(row)
    assert_instance_of(FasterCSV::Row, row)
    assert_equal([%w{my A}, %w{new B}, %w{headers C}], row.to_a)

    # third data row
    row = csv.shift
    assert_not_nil(row)
    assert_instance_of(FasterCSV::Row, row)
    assert_equal([%w{my 1}, %w{new 2}, %w{headers 3}], row.to_a)

    # empty
    assert_nil(csv.shift)
    
    # with return and convert
    assert_nothing_raised(Exception) do
      csv = FasterCSV.parse(@data, :headers           => "my,new,headers",
                                   :return_headers    => true,
                                   :header_converters => :symbol )
    end
    row = csv.shift
    assert_not_nil(row)
    assert_instance_of(FasterCSV::Row, row)
    assert_equal( [[:my, "my"], [:new, "new"], [:headers, "headers"]],
                  row.to_a )
    assert(row.header_row?)
    assert(!row.field_row?)
  end
  
  def test_return_headers
    # activate headers and request they are returned
    csv = nil
    assert_nothing_raised(Exception) do
      csv = FasterCSV.parse(@data, :headers => true, :return_headers => true)
    end

    # header row
    row = csv.shift
    assert_not_nil(row)
    assert_instance_of(FasterCSV::Row, row)
    assert_equal( [%w{first first}, %w{second second}, %w{third third}],
                  row.to_a )
    assert(row.header_row?)
    assert(!row.field_row?)

    # first data row - skipping headers
    row = csv.shift
    assert_not_nil(row)
    assert_instance_of(FasterCSV::Row, row)
    assert_equal([%w{first A}, %w{second B}, %w{third C}], row.to_a)
    assert(!row.header_row?)
    assert(row.field_row?)

    # second data row
    row = csv.shift
    assert_not_nil(row)
    assert_instance_of(FasterCSV::Row, row)
    assert_equal([%w{first 1}, %w{second 2}, %w{third 3}], row.to_a)
    assert(!row.header_row?)
    assert(row.field_row?)

    # empty
    assert_nil(csv.shift)
  end
  
  def test_converters
    # create test data where headers and fields look alike
    data = <<-END_MATCHING_CSV.gsub(/^\s+/, "")
    1,2,3
    1,2,3
    END_MATCHING_CSV
    
    # normal converters do not affect headers
    csv = FasterCSV.parse( data, :headers        => true,
                                 :return_headers => true,
                                 :converters     => :numeric )
    assert_equal([%w{1 1}, %w{2 2}, %w{3 3}], csv.shift.to_a)
    assert_equal([["1", 1], ["2", 2], ["3", 3]], csv.shift.to_a)
    assert_nil(csv.shift)
    
    # header converters do affect headers (only)
    assert_nothing_raised(Exception) do 
      csv = FasterCSV.parse( data, :headers           => true,
                                   :return_headers    => true,
                                   :converters        => :numeric,
                                   :header_converters => :symbol )
    end
    assert_equal([[:"1", "1"], [:"2", "2"], [:"3", "3"]], csv.shift.to_a)
    assert_equal([[:"1", 1], [:"2", 2], [:"3", 3]], csv.shift.to_a)
    assert_nil(csv.shift)
  end
  
  def test_builtin_downcase_converter
    csv = FasterCSV.parse( "One,TWO Three", :headers           => true,
                                            :return_headers    => true,
                                            :header_converters => :downcase )
    assert_equal(%w{one two\ three}, csv.shift.headers)
  end
  
  def test_builtin_symbol_converter
    csv = FasterCSV.parse( "One,TWO Three", :headers           => true,
                                            :return_headers    => true,
                                            :header_converters => :symbol )
    assert_equal([:one, :two_three], csv.shift.headers)
  end
  
  def test_custom_converter
    converter = lambda { |header| header.tr(" ", "_") }
    csv       = FasterCSV.parse( "One,TWO Three",
                                 :headers           => true,
                                 :return_headers    => true,
                                 :header_converters => converter )
    assert_equal(%w{One TWO_Three}, csv.shift.headers)
  end
end
