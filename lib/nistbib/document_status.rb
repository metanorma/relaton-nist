module NistBib
  class DocumentStatus
    STAGES = %w[
      draft-internal draft-wip draft-prelim draft-public draft-retire
      draft-withdrawn final final-review final-withdrawn
    ].freeze

    # @return [String]
    attr_reader :stage

    # @return [String, NilClass]
    attr_reader :substage

    # @return [String, NilClass]
    attr_reader :iteration

    # @param stage [String]
    # @param substage [String, NilClass]
    # @param iteration [String, NilClass]
    def initialize(stage:, substage: nil, iteration: nil)
      unless STAGES.include? stage
        raise ArgumentError, "invalid argument: stage (#{stage})"
      end

      @stage = stage
      @substage = substage
      @iteration = iteration
    end

    # @param builder [Nokogiri::XML::Builder]
    def to_xml(builder)
      builder.status do
        builder.stage stage
        builder.iteration iteration if iteration
      end
    end
  end
end
