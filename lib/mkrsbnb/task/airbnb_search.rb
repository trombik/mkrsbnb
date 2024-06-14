# frozen_string_literal: true

require "date"
require "json"
require "selenium-webdriver"
require "pathname"

module Mkrsbnb
  class Task
    # A task to browse search page and dump the HAR file

    # rubocop:disable Metrics/ClassLength
    class AirbnbSearch
      class AddOnNotFound < StandardError
      end

      # @param [Hash] opts The option hash
      # @option opts [String] :location The location to search
      # @option opts [String] :addon_dir Path to a directory to install add-ons from
      # @option opts [TrueClass|FalseClass] :headless Run the driver with or without window
      # @option opts :log_level [:info, :debug, :crit]
      # @option opts [String] :file A file name to dump HAR
      # @option opts [Integer] :max_price Max price to filter the search
      def initialize(opts)
        @opts = { location: "Krong-Siem-Reap--Siem-Reap--Cambodia",
                  addon_dir: Dir.pwd,
                  headless: true,
                  log_level: :info,
                  file: "out.har",
                  max_price: 30 }
        @opts.merge!(opts)
      end

      def date_checkin
        return @date_checkin if @date_checkin

        @date_checkin = Date.today + 7
      end

      def date_checkout
        date_checkin + 2
      end

      def filter_button
        driver.find_element(xpath: "//span[contains(text(), 'Filters')]")
      end

      def max_input
        driver.find_element(xpath: "//input[@id='price_filter_max']")
      end

      def show_link
        driver.find_element(xpath: "//a[contains(text(), 'Show') and contains(text(), 'places')]")
      end

      # rubocop:disable Metrics/AbcSize
      def set_filters
        # open the filter dialog
        driver.action
              .move_to(filter_button)
              .pause(duration: 3).click
              .perform

        # clear the input form.
        # XXX you cannot use Selenium::WebDriver::Element#clear here because the
        # input triggers an event
        max_input.send_keys [:control, "a"], :backspace

        # set the max price
        max_input.send_keys @opts[:max_price].to_s

        # click "Show N places" button
        driver.action
              .pause(duration: 3).move_to(show_link)
              .pause(duration: 2).click
              .perform
      end
      # rubocop:enable Metrics/AbcSize

      def next_button
        driver.find_element(xpath: "//a[contains(@aria-label,'Next') and contains(@href, '#{@location}')]")
      end

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      def click_next_until_last
        loop do
          begin
            next_button
          rescue Selenium::WebDriver::Error::NoSuchElementError
            break
          end

          # use script in browser instead of moveToElement
          # see https://github.com/mozilla/geckodriver/issues/776
          driver.execute_script("arguments[0].scrollIntoView();", next_button)
          driver.action
                .pause(duration: 5)
                .scroll_by(0, next_button.location.y.to_i)
                .perform
          driver.action
                .move_to(next_button)
                .click
                .pause(duration: rand(2..4))
                .perform
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      def install_addons(addons)
        addons = addons.is_a?(Array) ? addons : [addons]
        addons.each do |addon|
          logger.debug "Installing an addon `#{addon}`"
          install_addon(addon)
        end
      end

      def install_addon(addon)
        path = Pathname.new(@opts[:addon_dir]) / addon
        raise AddOnNotFound, "Add-on file `#{path}` does not exists." unless File.exist?(path)

        driver.install_addon(addon)
      end

      def logger
        Selenium::WebDriver.logger.level = @opts[:log_level]
        Selenium::WebDriver.logger
      end

      def profile
        return @profile if @profile

        @profile = Selenium::WebDriver::Firefox::Profile.new
        ENV["MOZ_REMOTE_SETTINGS_DEVTOOLS"] = "1"

        # enable netmonitor so that HAR can be saved.
        @profile["devtools.toolbox.selectedTool"] = "netmonitor"

        # enable persistlog so taht logs can be collected even when opening another
        # page
        @profile["devtools.netmonitor.persistlog"] = true

        @profile["general.useragent.override"] = ua
        @profile
      end

      def ua
        return @ua if @ua

        @ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " \
              "(KHTML, like Gecko) Chrome/73.0.3663.1 Safari/537.36"
      end

      def options
        return @options if @options

        @options = Selenium::WebDriver::Options.firefox profile: profile
        @options.add_argument("--headless") if @opts[:headless]

        # open devtools upon starting
        @options.add_argument("--devtools")
        @options
      end

      # rubocop:disable Metrics/MethodLength
      def driver
        return @driver if @driver

        @driver = Selenium::WebDriver.for :firefox, options: options
        @driver.manage.timeouts.script = 300
        @driver.manage.window.resize_to(1080, 1020)
        @driver.manage.timeouts.implicit_wait = 20
        begin
          install_addons("har_export_trigger-0.6.2resigned1.xpi")
        rescue AddOnNotFound => e
          logger.crit "Add-on `har_export_trigger-0.6.2resigned1.xpi` cannot be found. " \
                      "Download it from: " \
                      "https://addons.mozilla.org/en-US/firefox/addon/har-export-trigger/"
          raise e
        end
        @driver
      end
      # rubocop:enable Metrics/MethodLength

      def dump_har(file)
        logger.info("Dumping HAR")
        level = logger.level
        logger.level = :info
        har = driver.execute_async_script("HAR.triggerExport().then(arguments[0]);")
        har = { "log" => har }
        logger.level = level
        File.write(file, har.to_json)
        logger.info("Dumped")
      end

      def visit_search_page
        driver.navigate.to "https://www.airbnb.com/s/#{@opts[:location]}/homes" \
                           "?tab_id=home_tab&refinement_paths[]=%2Fhomes&" \
                           "flexible_trip_lengths[]=one_week&" \
                           "monthly_start_date=#{date_checkin}" \
                           "&monthly_length=3&monthly_end_date=#{date_checkin + 90}&" \
                           "price_filter_input_type=0&channel=EXPLORE&date_picker_type=calendar&" \
                           "checkin=#{date_checkin}&checkout=#{date_checkout}&adults=2"
        driver.action.pause(duration: 15).perform
      end

      def do_task
        visit_search_page
        set_filters
        click_next_until_last
        dump_har(@opts[:file])
      end

      # rubocop:disable Metrics/MethodLength
      def run
        started = Time.now
        logger.info("Started #{started}")
        trap "INT" do
          @driver&.quit
        end
        begin
          do_task
        rescue StandardError => e
          raise e
        ensure
          driver.quit
          logger.info("Total time in sec: #{Time.now - started}")
        end
      end
      # rubocop:enable Metrics/MethodLength
    end
    # rubocop:enable Metrics/ClassLength
  end
end
