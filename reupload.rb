require 'fileutils'
require 'open-uri'
require 'yaml'
require 'json'

PLATFORM_ANDROID = "android"
PLATFORM_IOS = "ios"
EXTENSION_APK = "apk"
EXTENSION_IPA = "ipa"
WORK_DIR = "./work"
SETTINGS = YAML.load_file('settings.yaml');

SETTINGS['APPS'].each { |appInfo|
  p "start #{appInfo['PACKAGE']}(#{appInfo['PLATFORM']}) re-upload."
  FileUtils.mkdir_p(WORK_DIR) unless File.exist?(WORK_DIR)
  url = "https://deploygate.com/api/users/#{SETTINGS['BEFORE']['USERNAME']}/platforms/#{appInfo['PLATFORM']}/apps/#{appInfo['PACKAGE']}/binaries?token=#{SETTINGS['BEFORE']['API_KEY']}"
  res = JSON.parse(open(url).read)
  raise "revision acquisition failure. please check settings.yaml" unless (res['error'] == false)
  apps = res['results']['binaries']
  apps.sort_by! { |app| app['revision'] }
  downloadDir = "#{WORK_DIR}/#{appInfo['PACKAGE']}"
  FileUtils.mkdir_p(downloadDir) unless File.exist?(downloadDir)
  apps.each { |app|
    # download
    fileName = "#{downloadDir}/#{app['version_name']}_#{app['revision']}.#{(appInfo['PLATFORM'] == PLATFORM_ANDROID) ? EXTENSION_APK : EXTENSION_IPA}"
    p "save file: #{fileName}"
    open(fileName, 'wb') do |output|
      open(app['file']) do |data|
        output.write(data.read)
      end
    end

    # upload
    param_url = "https://deploygate.com/api/users/#{(appInfo['AFTER_GROUP'] == nil) ? SETTINGS['AFTER']['USERNAME'] : appInfo['AFTER_GROUP']}/apps"
    param_file = "file=@" + fileName
    param_message = "message=" + app['message']
    response = JSON.load(IO.popen(['curl', '-s', '-F', param_file, '-F',  "token=#{SETTINGS['AFTER']['API_KEY']}", '-F', param_message, param_url], 'r', &:read))
    p "revision #{app['revision']} upload -> #{response['error'].to_s == "false" ? "Success!!" : "Fail"}"
  }
  # delete work dir
  FileUtils.rm_rf(WORK_DIR)
  p "#{appInfo['PACKAGE']}(#{appInfo['PLATFORM']}) #{apps.size} upload complete."
}
p "all task complete."
