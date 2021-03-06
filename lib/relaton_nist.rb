require "relaton_nist/version"
require "relaton_nist/nist_bibliography"

# if defined? Relaton
#   require_relative "relaton/processor"
#   Relaton::Registry.instance.register(Relaton::RelatonNist::Processor)
# end

module RelatonNist
  class Error < StandardError; end

  # Returns hash of XML reammar
  # @return [String]
  def self.grammar_hash
    gem_path = File.expand_path "..", __dir__
    grammars_path = File.join gem_path, "grammars", "*"
    grammars = Dir[grammars_path].sort.map { |gp| File.read gp }.join
    Digest::MD5.hexdigest grammars
  end
end
