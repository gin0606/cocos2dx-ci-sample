class Environment
  def self.travis?
    !!ENV['TRAVIS']
  end

  # PullRequestはbranch名の最後が`_android`で終わってたらAndroidビルドする
  # PullRequestではない場合masterとadhocの時のみAndroidビルドする
  def self.build_android?
    return true unless travis?
    return true if can_adhoc?
    return true if travis_branch_end_with? '_android'
    unless travis_pull_request?
      return (travis_branch_is? "master" or travis_branch_is? "adhoc")
    end
    return false
  end

  # Travis上での実行じゃなかったらadhoc配信OK
  # Travis上だったらPRではない && adhocブランチなら配信
  def self.can_adhoc?
    (!travis? or (!travis_pull_request? and travis_branch_is? "adhoc"))
  end

  def self.travis_pull_request?
    travis? and ENV['TRAVIS_PULL_REQUEST'] != "false"
  end

  def self.travis_branch_is? branch
    ENV['TRAVIS_BRANCH'] == branch
  end

  def self.travis_branch_end_with? suffix
    ENV['TRAVIS_BRANCH'].end_with? suffix
  end

  def self.has_variables *keys
    keys.each {|key|
      fail "'#{key}' is need in ENV" unless ENV[key]
    }
  end
end

if __FILE__ == $0
  method_name = ARGV[0]
  exit Environment.send method_name
end
