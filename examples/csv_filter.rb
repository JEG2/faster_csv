#!/usr/local/bin/ruby -w

require "faster_csv"

running_total = 0
FasterCSV.filter( :headers           => true,
                  :return_headers    => true,
                  :header_converters => :symbol,
                  :converters        => :numeric ) do |row|
  if row.header_row?
    row << "Running Total"
  else
    row << (running_total += row[:quantity] * row[:price])
  end
end
