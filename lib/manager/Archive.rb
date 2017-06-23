require File.dirname(__FILE__) + '/../Config.rb'

class Archive
  attr_accessor :environment

  def initialize(environment)
    @environment = environment
    Archive.archives[environment.locale] = self
  end

  def combine_path(id)
    locale = @environment.locale
    archive_path = Config.archive_path locale
    File.join archive_path, "/#{id}#{Config.mse_output_appendix}"
  end

  def [](id)
    IO.read combine_path id
  end

  def []=(id, value)
    IO.write combine_path(id), value
  end

  def remove(id)
    File.delete combine_path(id)
  end

  def pull

  end

  def post

  end

  def set(id, file)

  end

  def state
    ['ok', '']
  end
end

class Archive
  class << self
    attr_accessor :archives
    def initialize
      @archives = {}
    end

    def [](locale)
      @archives.key?(locale) ? @archives[locale] : Archive.new(Ygoruby::Environment[locale])
    end
  end
end

Archive.initialize