#!/usr/local/bin/ruby -w

# tc_speed.rb
#
#  Created by James Edward Gray II on 2005-11-14.
#  Copyright 2005 Gray Productions. All rights reserved.

require "test/unit"

require "faster_csv"
require "csv"

class TestFasterCSVSpeed < Test::Unit::TestCase
  PATH = File.join(File.dirname(__FILE__), "test_data.csv")
  
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
end
