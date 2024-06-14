# frozen_string_literal: true

require "ostruct"
require "json"

# StaysSearchResponse
module Mkrsbnb
  class Airbnb
    # A class that contains listings
    class StaysSearchResponse
      def initialize(str)
        @data = str.is_a?(String) ? JSON.parse(str, object_class: OpenStruct) : str
        unless @data.__typename == "StaysSearchResponse"
          raise "Type is not StaysSearchResponse but `#{@data.__typename}`"
        end

        @listings = []
      end

      def listings
        @data.searchResults.select { |r| r.__typename == "StaySearchResult" }.each do |result|
          @listings << StaySearchResult.new(result)
        end
        @listings.compact!
        @listings
      end
    end

    # A class that contains listings
    class StaysMapSearchResponse
      def initialize(str)
        @data = str.is_a?(String) ? JSON.parse(str, object_class: OpenStruct) : str
        unless @data.__typename == "StaysMapSearchResponse"
          raise "Type is not StaysMapSearchResponse but `#{@data.__typename}`"
        end

        @listings = []
      end

      def listings
        @data.mapSearchResults.select { |r| r.__typename == "StaySearchResult" }.each do |result|
          @listings << StaySearchResult.new(result)
        end
        @listings.compact!
        @listings
      end
    end
  end
end
