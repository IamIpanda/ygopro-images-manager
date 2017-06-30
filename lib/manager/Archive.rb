require File.dirname(__FILE__) + '/../Config.rb'
require 'json'

class Archive
  attr_accessor :environment

  def initialize(environment)
    @environment = environment
    Archive.archives[environment.locale] = self
  end

  def archive_path
    Config.archive_path @environment.locale
  end

  def archive_dist_path
    Config.archive_dist_path @environment.locale
  end

  def archive_dist_thumbnail_path
    File.join(archive_dist_path, 'thumbnail/')
  end

  def combine_path(id)
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
    GitManager.images_raw_repo.pull_latest_release(Config.archive_dist_pack(@environment.locale))
  end

  def push

  end

  def state
    ['ok', '']
  end

  def process
    Dir.mkdir archive_dist_path unless Dir.exist? archive_dist_path
    Dir.mkdir archive_dist_thumbnail_path unless Dir.exist? archive_dist_thumbnail_path
    command = "ls -1 #{archive_path} | sed -e \"s/\\.png$//\" | xargs -I {} magick \"#{archive_path}{}#{Config.mse_output_appendix}\" \\( +clone -resize 177x254! -write \"#{archive_dist_path}{}.jpg\" +delete \\) -resize 44x64! \"#{archive_dist_thumbnail_path}{}.jpg\""
    ygopro_images_manager_logger.info "Processing command:" + command
    exec command
  end

  def pack
    require 'zip'
    ygopro_images_manager_logger.info "Packing archive [#{@environment.locale}] #{archive_dist_path}"
    Zip::File.open(Config.archive_dist_pack(@environment.locale), Zip::File::CREATE) do |zip_file|
      Dir.glob(archive_dist_path + '*.jpg').each do |file|
        ygopro_images_manager_logger.debug "Archive [#{@environment.locale}] is packing dist #{file}"
        zip_file.add(File.basename(file), file) { true }
      end
      Dir.glob(archive_dist_thumbnail_path + '*.jpg').each do |file|
        ygopro_images_manager_logger.debug "Archive [#{@environment.locale}] is packing dist #{file}"
        zip_file.add('thumbnail/' + File.basename(file), file) { true }
      end
    end
  end

  def self.auth
    require 'net/http'
    uri = URI('https://api.github.com')
    req = Net::HTTP::Get.new(uri)
    req.basic_auth 'username', 'password'
    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    res = http.start do |http_client|
      http_client.request(req)
    end
    JSON.parse res.body
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