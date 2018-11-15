require 'sinatra'
require File.dirname(__FILE__) + '/Manager.rb'
require File.dirname(__FILE__) + '/../Config.rb'
require File.dirname(__FILE__) + '/../Thread.rb'
require 'json'

connections = []

set :server, :thin

# 权限验证

# get '/*' do
#   pass if params['authorization_key'] == Config.server_authorization_key
#   403
# end

# post '/*' do
#   pass if params['authorization_key'] == Config.server_authorization_key
#   403
# end

# 获取当前状态
get '/state' do

end

get '/locale_list' do
  Ygoruby::Environment.valid_locale_list.to_json
end

# 获取日志
get '/log' do
  content_type 'text/event-stream'
  stream :keep_open do |out|
    connections << out
    log_hook = ygopro_images_manager_logger.register_trigger do |message, line|
      out << "data: #{line}\r\n\n"
    end
    out.callback do
      connections.delete out
      ygopro_images_manager_logger.unregister_trigger log_hook
    end
  end
end

# 获取存档状态
get %r{/archive/([a-zA-Z\-]+)/state} do
  archive = Archive[params['capture'][0]]
  archive.state
end

# 令存档从Git同步
post %r{/archive/([a-zA-Z\-]+)/pull} do
  archive = Archive[params['captures'][0]]
  result = ImageProcessThread.execute(description) { archive.pull }
  result ? [200, 'into the thread.'] : [504, 'busy']
end

# 令存档上传至Git
post %r{/archive/([a-zA-Z\-]+)/push} do
  archive = Archive[params['captures'][0]]
  result = ImageProcessThread.execute(description) { archive.push }
  result ? [200, 'into the thread.'] : [504, 'busy']
end

# 处理存档，打包并上传至Git
post %r{/archive/([a-zA-Z\-]+)/full_push} do
  archive = Archive[params['captures'][0]]
  result = ImageProcessThread.execute(description) do
    archive.process
    archive.pack
    archive.push
  end
  result ? [200, 'into the thread.'] : [504, 'busy']
end

# 处理存档
post %r{/archive/([a-zA-Z\-]+)/process} do
  archive = Archive[params['captures'][0]]
  result = ImageProcessThread.execute(description) { archive.process }
  result ? [200, 'into the thread.'] : [504, 'busy']
end

# 打包处理后的存档图片
post %r{/archive/([a-zA-Z\-]+)/pack} do
  archive = Archive[params['captures'][0]]
  result = ImageProcessThread.execute(description) { archive.pack }
  result ? [200, 'into the thread.'] : [504, 'busy']
end

# 获得存档中的某张图片
get %r{/archive/([a-zA-Z\-]+)/(\d+)} do
  archive = Archive[params['captures'][0]]
  id = params['captures'][1].to_i
  content_type 'image/png'
  archive[id]
end

# 设置存档中的某张图片
post %r{/archive/([a-zA-Z\-]+)/(\d+)} do
  archive = Archive[params['captures'][0]]
  id = params['captures'][1].to_i
  data = request.body.read
  archive[id] = data
  'ok'
end

# 获得数据库状态
get '/database/state' do
  GitManager.database_repo.full_status
end

# 令数据库从 Git 同步
post '/database/pull' do
  GitManager.database_repo.pull
end

# 获得中间图的状态
get '/raw/state' do
  GitManager.images_raw_repo.full_status
end

# 令中间图从 Git 同步
post '/raw/pull' do
  GitManager.images_raw_repo.pull
end

# 获得 MSE 状态
get '/mse/state' do
  GitManager.mse_repo.full_status
end

# 令 MSE 从 Git 同步
post '/mse/pull' do
  GitManager.mse_repo.pull
end

# 获取MSE模板和语料
get '/mse/model' do
    [IO.read(File.dirname(__FILE__) + '/../mse/MSEModel.erb'), IO.read(File.dirname(__FILE__) + '/../mse/MSECorpus.yaml')].to_json
end

get '/config' do
  IO.read(File.dirname(__FILE__) + '/../Config.yaml')
end

# 设置MSE模板和语料
post '/mse/model' do
  setting = JSON.parse request.body.read
  target = setting['target']
  body = setting['body']
  if target == nil or body == nil
    ygorpo_images_manager_logger.info 'Not enough or right parameter for mse model setting.'
    400
  else
    case target
      when 'model'
        MSEHelp.set_model body
        'ok'
      when 'corpus'
        MSEHelp.set_corpus body
        'ok'
      when 'config'
        IO.write(File.dirname(__FILE__) + '/../Config.yaml', body)
        Config.initialize
        'ok'
      else
        ygopro_images_manager_logger.warn 'Unknown model setting parameter' + target
        400
    end
  end
end

# 将MSE模板和语料上传（会更改本Repo本身）
post '/mse/model/push' do
  GitManager.current_repo.push
end

# 获取中间图的状态
get '/raw/state' do
  GitManager.images_raw_repo.full_status
end

# 令中间图从Git拖取
post '/raw/pull' do
  GitManager.images_raw_repo.pull
end

# 更新某张中间图
post %r{/raw/([a-zA-Z\-]+)/(\d+)} do
  locale = params['captures'][0]
  id = params['captures'][1]
  body = request.body.read
  IO.write Config.images_path + "/#{id}.jpg", body
  'ok'
end

get '/run/state' do
  [ImageProcessThread.is_busy?, ImageProcessThread.last_commit_time, ImageProcessThread.last_commit_description].to_json
end

post '/run/abort' do
  result = ImageProcessThread.abort
  result ? [200, 'into the thread.'] : [412, 'ok']
end

# 对于每一个语言，对比前后变动并上传
post '/run/all/diff' do
  description = request.body.read
  result = ImageProcessThread.execute(description) { Ygoruby::Environment.valid_locale_list.each { |locale| YgoproImagesManager.run_diff locale } }
  result ? [200, 'into the thread.'] : [504, 'busy']
end

# 对于每一个语言，重新生成所有卡图
post '/run/all/all' do
  description = request.body.read
  result = ImageProcessThread.execute(description) { Ygoruby::Environment.valid_locale_list.each { |locale| YgoproImagesManager.run_all locale } }
  result ? [200, 'into the thread.'] : [504, 'busy']
end

# 对比前后变动并上传
post %r{/run/([a-zA-Z\-]+)/diff} do
  locale = params['captures'][0]
  description = request.body.read
  result = ImageProcessThread.execute(description) { YgoproImagesManager.run_diff locale }
  result ? [200, 'into the thread.'] : [504, 'busy']
end

# 重新生成所有卡图
post %r{/run/([a-zA-Z\-]+)/all} do
  locale = params['captures'][0]
  description = request.body.read
  result = ImageProcessThread.execute(description) { YgoproImagesManager.run_all locale }
  result ? [200, 'into the thread.'] : [504, 'busy']
end


# 立即生成目标（单张）卡图
get %r{/run/([a-zA-Z\-]+)/(\d+)} do
  locale = params['captures'][0]
  id = params['captures'][1]
  content_type 'image/png'
  YgoproImagesManager.run_id locale, id.to_i
end

post %r{/run/([a-zA-Z\-]+)/(\d+)} do
  locale = params['captures'][0]
  id = params['captures'][1]
  content_type 'image/png'
  YgoproImagesManager.run_id locale, id.to_i, true
end

set :bind, '0.0.0.0'
