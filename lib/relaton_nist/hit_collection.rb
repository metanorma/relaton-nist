# frozen_string_literal: true

require "zip"
require "fileutils"
require "relaton_nist/hit"
require "addressable/uri"
require "open-uri"

module RelatonNist
  # Page of hit collection.
  class HitCollection < RelatonBib::HitCollection
    DOMAIN = "https://csrc.nist.gov"
    PUBS_EXPORT = URI.join(DOMAIN, "/CSRC/media/feeds/metanorma/pubs-export")
    DATAFILEDIR = File.expand_path ".relaton/nist", Dir.home
    DATAFILE = File.expand_path "pubs-export.zip", DATAFILEDIR

    # @param ref_nbr [String]
    # @param year [String]
    # @param opts [Hash]
    # @option opts [String] :stage
    def initialize(ref_nbr, year = nil, opts = {}) # rubocop:disable Metrics/AbcSize
      super ref_nbr, year

      /(?<docid>(SP|FIPS)\s[0-9-]+\w?)/ =~ text
      @array = docid ? from_json(docid, **opts) : from_csrc(**opts)

      @array.sort! do |a, b|
        if a.sort_value != b.sort_value
          b.sort_value - a.sort_value
        else
          (b.hit[:release_date] - a.hit[:release_date]).to_i
        end
      end
    end

    private

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

    # @param stage [String]
    # @return [Array<RelatonNist::Hit>]
    def from_csrc(**opts)
      from, to = nil
      if year
        d    = Date.strptime year, "%Y"
        from = d.strftime "%m/%d/%Y"
        to   = d.next_year.prev_day.strftime "%m/%d/%Y"
      end
      url = "#{DOMAIN}/publications/search?keywords-lg=#{text}"\
        "&sortBy-lg=relevence"
      url += "&dateFrom-lg=#{from}" if from
      url += "&dateTo-lg=#{to}" if to
      url += if /PD/.match? opts[:stage]
               "&status-lg=Draft,Retired Draft,Withdrawn"
             else
               "&status-lg=Final,Withdrawn"
             end

      doc = Nokogiri::HTML OpenURI.open_uri(::Addressable::URI.parse(url).normalize)
      doc.css("table.publications-table > tbody > tr").map do |h|
        link  = h.at("td/div/strong/a")
        serie = h.at("td[1]").text.strip
        code  = h.at("td[2]").text.strip
        title = link.text
        doc_url = DOMAIN + link[:href]
        status = h.at("td[4]").text.strip.downcase
        release_date = Date.strptime h.at("td[5]").text.strip, "%m/%d/%Y"
        Hit.new(
          {
            code: code, serie: serie, title: title, url: doc_url,
            status: status, release_date: release_date
          }, self
        )
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # Fetches data form json
    # @param docid [String]
    # @param stage [String]
    # @return [Array<RelatonNist::Hit>]
    def from_json(docid, **opts)
      select_data(docid, **opts).map do |h|
        /(?<serie>(?<=-)\w+$)/ =~ h["series"]
        title = [h["title-main"], h["title-sub"]].compact.join " - "
        release_date = RelatonBib.parse_date h["published-date"]
        Hit.new({ code: h["docidentifier"], serie: serie.upcase, title: title,
                  url: h["uri"], status: h["status"],
                  release_date: release_date, json: h }, self)
      end
    end

    # @param docid [String]
    # @param stage [String]
    # @return [Array<Hach>]
    def select_data(docid, **opts) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength,Metrics/PerceivedComplexity
      d = Date.strptime year, "%Y" if year
      didrx = Regexp.new(docid)
      data.select do |doc|
        next unless match_year?(doc, d)

        if /PD/.match? opts[:stage]
          next unless %w[draft-public draft-prelim].include? doc["status"]
        else
          next unless doc["status"] == "final"
        end
        doc["docidentifier"] =~ didrx
      end
    end

    # @param doc [Hash]
    # @param date [Date] first day of year
    # @return [TrueClass, FalseClass]
    def match_year?(doc, date)
      return true unless year

      idate = RelatonBib.parse_date doc["issued-date"]
      idate.between? date, date.next_year.prev_day
    end

    # Fetches json data form server
    # @return [Hash]
    def data
      ctime = File.ctime DATAFILE if File.exist? DATAFILE
      if !ctime || ctime.to_date < Date.today
        fetch_data(ctime)
      end
      unzip
    end

    # Fetch data form server and save it to file
    #
    # @prarm ctime [Time, NilClass]
    def fetch_data(ctime)
      resp = OpenURI.open_uri("#{PUBS_EXPORT}.meta")
      if !ctime || ctime < resp.last_modified
        @data = nil
        FileUtils.mkdir_p DATAFILEDIR unless Dir.exist? DATAFILEDIR
        IO.copy_stream(URI.open("#{PUBS_EXPORT}.zip"), DATAFILE)
      end
    end

    # upack zip file
    #
    # @return [Hash]
    def unzip
      return @data if @data

      Zip::File.open(DATAFILE) do |zf|
        zf.each do |f|
          @data = JSON.parse f.get_input_stream.read
          break
        end
      end
      @data
    end
  end
end
