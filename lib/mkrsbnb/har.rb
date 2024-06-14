# frozen_string_literal: true

require "json"
require "ostruct"
require "date"

require "mkrsbnb/airbnb/result"
require "mkrsbnb/airbnb/response"

module Mkrsbnb
  # A class to parse a HAR file and JSON responses
  class HAR
    API_PATH_RE = %r{/api/v\d+/(?:StaysSearch|StaysMapS2Search)/}

    def initialize(str)
      @data = JSON.parse(str, object_class: OpenStruct)
      @data.log.entries = select_search_result
      @listings = []
      @map_results = []
    end

    def datetime
      DateTime.parse(@data.log.entries.first.startedDateTime)
    end

    def search_results
      return @map_results if @map_results.size.positive?

      @map_results = process_results.flatten
    end

    def dump_response
      @data.log.entries.map { |e| JSON.parse(e.response.content.text) }
    end

    private

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def process_results
      results = []
      @data.log.entries.each do |e|
        obj = JSON.parse(e.response.content.text, object_class: OpenStruct)

        # listing is in two different types:
        # result.data.presentation.staysSearch.results.mapSearchResults
        # result.data.presentation.staysSearch.results.searchResults
        #
        # SkinnyListingItem is, probably, a cached StaySearchResult, which does
        # not include details like name, price, and review score
        if obj.data.presentation.staysSearch.results.searchResults
          results << Mkrsbnb::Airbnb::StaysSearchResponse.new(obj.data.presentation.staysSearch.results)
        end
        stays_map_search_response = obj.data.presentation.staysSearch.mapResults
        if stays_map_search_response && stays_map_search_response.__typename == "StaySearchResult"
          results << Mkrsbnb::Airbnb::StaysMapSearchResponse.new(stays_map_search_response).listings
        end
      end
      results
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def staysearch?(entry)
      API_PATH_RE.match?(entry.request.url) && entry.request.method == "POST" && entry.response.status == 200
    end

    def select_search_result
      @data.log.entries.select { |e| staysearch?(e) }
    end
  end
end
