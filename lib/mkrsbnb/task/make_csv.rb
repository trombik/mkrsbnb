# frozen_string_literal: true

require "csv"
require "mkrsbnb/har"
require "mkrsbnb/task/make_csv"

module Mkrsbnb
  class Task
    # A task to generate CSV file
    class MakeCSV
      def initialize(file: "", csv_file: "", reject_no_review: true)
        raise ArgumentError, "file and csv_file are mandatory argments" if file.empty? || csv_file.empty?

        @reject_no_review = reject_no_review
        @csv_file = csv_file
        @file = file
      end

      def self.exit_on_failure?
        true
      end

      def har(file)
        HAR.new(File.read(file))
      end

      def parse(file)
        all_listings = []
        har(file).search_results.each do |r|
          r.listings.each do |l|
            next if @reject_no_review && l.review_total.to_i.zero?

            all_listings << l
          end
        end
        all_listings.uniq!(&:id)
        all_listings
      end

      def make_csv(listings)
        CSV.generate do |csv|
          csv << ["ID", "Name", "Review score", "Review total", "Price", "Superhost", "Guest favourite"]
          listings.each do |l|
            csv << [l.id.to_s, l.name, l.review_score, l.review_total, l.price_int, l.superhost, l.guest_favorite]
          end
        end
      end

      def write_file(file, content)
        if file == "-"
          puts content
        else
          File.open(file, "w") do |f|
            f.puts content
          end
        end
      end

      def run
        all_listings = parse(@file)
        csv = make_csv(all_listings)
        write_file(@csv_file, csv)
      end
    end
  end
end
