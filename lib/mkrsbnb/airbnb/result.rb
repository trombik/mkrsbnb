# frozen_string_literal: true

require "ostruct"
require "json"

module Mkrsbnb
  class Airbnb
    # StaySearchResult represents the listing. In the result, there are many
    # other attributes, but here, implements what we care only.
    class StaySearchResult
      def initialize(str)
        @data = str.is_a?(String) ? JSON.parse(str, object_class: OpenStruct) : str
        raise "Type is not StaySearchResult but `#{@data.__typename}`" unless @data.__typename == "StaySearchResult"

        @listings = []
      end

      def review_score
        matched = /(\d+\.\d+)\s\(\d+\)/.match(@data.listing.avgRatingLocalized)
        matched ? matched[1].to_f : 0
      end

      def review_total
        matched = /\d+\.\d+\s\((\d+)\)/.match(@data.listing.avgRatingLocalized)
        matched ? matched[1] : 0
      end

      def price_str
        return "" unless primary_line

        primary_line.discountedPrice || primary_line.price
      end

      def price_int
        /(\d+)/.match(price_str.delete(","))[1].to_i
      end

      def guest_favorite
        formatted_badges_include?("GUEST_FAVORITE")
      end

      def superhost
        formatted_badges_include?("SUPERHOST")
      end

      def name
        @data.listing.name.delete("\n")
      end

      def id
        @data.listing.id
      end

      private

      def primary_line
        return unless @data.pricingQuote

        @data.pricingQuote.structuredStayDisplayPrice.primaryLine
      end

      def formatted_badges_include?(type)
        return false unless @data.listing.formattedBadges

        @data.listing.formattedBadges.each do |b|
          return true if b.loggingContext && b.loggingContext.badgeType == type
        end
        false
      end
    end
  end
end
