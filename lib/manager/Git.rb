require 'github_api'
require File.dirname(__FILE__) + '/../Config.rb'

class Git
  attr_accessor :path
  attr_accessor :source
  attr_accessor :branch
  # repo
  attr_accessor :author
  attr_accessor :repo_name

  def initialize
    @source = 'origin'
    @branch = 'master'
  end

  def self.open(path, repo_name = nil, author = 'moecube')
    repo = Git.new
    repo.path = path
    repo.author = author
    repo.repo_name = repo_name == nil ? File.basename(path) : repo_name
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
    result = `#{command}`
    ygopro_images_manager_logger.info result
    result
  end

  def push
    `cd #{path} && git commit -a && git push`
  end

  def full_status
    [status, last_change_time].to_json
  end

  def pull_latest_release(locale, dist)
    list = Github.repos.releases.list @author, @repo_name
    release = list[0]
    assets = release.assets
    asset = assets[3]
    uri = asset.browser_download_url
  end

  def push_leatest_release(locale, src)
    list = Github.repos.releases.list @author, @repo_name
    release = list[0]
    assets = release.assets
    asset = assets[3]
    github.repos.releases.assets.upload @author, @repo_name, release.id, src,
      name: 'xxx',
      content_type: 'application/octet-stream'
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