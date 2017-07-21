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
    if release == nil
      ygopro_images_manager_logger.warn "No release for #{@author}/#{@repo_name}. No file will be downloaded."
      return false
    else
      ygopro_images_manager_logger.info "Find release [#{release.id}]#{release.name}"
    end
    assets = release.assets
    asset = nil
    for asset in assets
      break if asset.name.include? "#{locale}.zip"
    end
    if asset == nil
      ygopro_images_manager_logger.warn "No file named #{locale}, No file will be downloaded."
      return false
    else
      ygopro_images_manager_logger.info "Find asset [#{asset.id}]#{asset.name}"
    end
    # curl 下载
    command = "curl -vLJo #{dist} -H 'Accept: application/octet-stream' 'https://api.github.com/repos/#{@author}/#{@repo_name}/releases/assets/#{asset.id}'"
    ygopro_images_manager_logger.info "Executing command #{command}"
    `#{command}`
    return true
  end

  def push_latest_release(locale, src, name)
    list = Github.repos.releases.list @author, @repo_name
    release = list[0]
    assets = release.assets
    asset = assets[3]
    github.repos.releases.assets.upload @author, @repo_name, release.id, src,
      name: name,
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
      @mse_repo = Git.open(Config.mse_path, 'MagicSetEditor')
      @database_repo = Git.open(Config.database_path + '/..', 'ygopro-database')
      @images_raw_repo = Git.open(Config.images_path + '/..', 'ygopro-images')
      @current_repo = Git.open(Config.basic_path)
      @mse_repo.branch = 'win32'
      Github.configure do |c|
        c.basic_auth = Config.github
      end
    end
  end
end

GitManager.initialize