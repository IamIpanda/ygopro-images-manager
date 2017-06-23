require File.dirname(__FILE__) + '/../Config.rb'

class Git
  attr_accessor :path
  attr_accessor :source
  attr_accessor :branch

  def initialize
    @source = 'origin'
    @branch = 'master'
  end

  def self.open(path)
    repo = Git.new
    repo.path = path
    repo
  end

  def status
    `cd #{path} && git status`
  end

  def last_change_time
    `cd #{path} && git log -1 --format=%cd`
  end

  def pull
    command = "cd #{path} && git pull #{@source} #{@branch}"
    `#{command}`
  end

  def push
    `cd #{path} && git commit -a && git push`
  end

  def full_status
    [status, last_change_time].to_json
  end
end

module GitManager
  class << self
    attr_accessor :mse_repo
    attr_accessor :database_repo
    attr_accessor :images_raw_repo
    attr_accessor :current_repo

    def initialize
      @mse_repo = Git.open(Config.mse_path)
      @database_repo = Git.open(Config.database_path + '/..')
      @images_raw_repo = Git.open(Config.images_path + '/..')
      @current_repo = Git.open(Config.basic_path)
      @mse_repo.branch = 'win32'
    end
  end
end

GitManager.initialize