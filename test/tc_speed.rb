#!/usr/local/bin/ruby -w

# tc_speed.rb
#
#  Created by James Edward Gray II on 2005-11-14.
#  Copyright 2005 Gray Productions. All rights reserved.

require "test/unit"
require "timeout"

require "faster_csv"
require "csv"

class TestFasterCSVSpeed < Test::Unit::TestCase
  PATH     = File.join(File.dirname(__FILE__), "test_data.csv")
  BIG_DATA = "123456789\n" * 1024
  
  def test_that_we_are_doing_the_same_work
    FasterCSV.open(PATH) do |csv|
      CSV.foreach(PATH) do |row|
        assert_equal(row, csv.shift)
      end
    end
  end
  
  def test_speed_vs_csv
    csv_time = Time.now
    CSV.foreach(PATH) do |row|
      # do nothing, we're just timing a read...
    end
    csv_time = Time.now - csv_time

    faster_csv_time = Time.now
    FasterCSV.foreach(PATH) do |row|
      # do nothing, we're just timing a read...
    end
    faster_csv_time = Time.now - faster_csv_time
    
    assert(faster_csv_time < csv_time / 3)
  end
  
  def test_the_parse_fails_fast_when_it_can_for_unquoted_fields
    data = 'valid,fields,bad start"' + BIG_DATA
    assert_raise(FasterCSV::MalformedCSVError) do
      Timeout.timeout(0.2) { FasterCSV.parse(data) }
    end
  end
  
  def test_the_parse_fails_fast_when_it_can_for_unescaped_quotes
    data = 'valid,fields,"bad start"unescaped' + BIG_DATA
    assert_raise(FasterCSV::MalformedCSVError) do
      Timeout.timeout(0.2) { FasterCSV.parse(data) }
    end
  end
end
