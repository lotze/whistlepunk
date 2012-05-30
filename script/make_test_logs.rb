#!/usr/bin/ruby

require 'rubygems'
require 'json'

class MakeTestLogs

  def write_logs(log_file, log_hashes)
    File.open(log_file, "w") do |file|
      log_hashes.sort_by {|l| l['timestamp'] || l[:timestamp]}.each do |l|
        file.puts l.to_json
      end
    end
  end

  def log_share(user_id, ts, share_id, overrides={})
    return [{:userId => user_id, :timestamp => ts, :eventName => 'objectShared', :shareHash => share_id, :share_method => 'myface'}.merge(overrides),
      {:userId => user_id, :timestamp => ts, :eventName => 'measureMe', :measureName => 'shared'}.merge(overrides),
      {:userId => user_id, :timestamp => ts, :eventName => 'measureMe', :measureName => 'value_ValueOne'}.merge(overrides)
      ]
  end

  def log_facebook_like(user_id, ts, share_id, overrides={})
    return [{:userId => user_id, :timestamp => ts, :eventName => 'facebookLiked', :shareHash => share_id}.merge(overrides)]
  end

  def measure_event(user_id, ts, measureName, overrides={})
    return [{:actorId => user_id, :timestamp => ts, :eventName => 'measureMe', :measureName => measureName, :measureTarget => '', :measureAmount => 1}.merge(overrides)]
  end

  def become_member(user_id, ts, new_state = 'member', overrides={})
    return [{:userId => user_id, :timestamp => ts, :eventName => 'membershipStatusChange', :newState => new_state}.merge(overrides)]
  end

  def create_member(user_id, ts, name, email, overrides={})
    return [{:userId => user_id, :timestamp => ts, :eventName => 'userCreated', :name => name, :email => email}.merge(overrides)]
  end

  def make_session_logs(user_id, first_request_at, session_length, is_first_session=false, in_from_share_id=nil, overrides={})
    user_agent = 'Chrome'
    first_referrer = 'http://somerandomsite.com'
    ip_address = "1.2.3.4"
    log_hashes = []
    request_time = first_request_at
    referrer_uri = first_referrer
    request_uri = "/randompage_#{rand(10)}"
    if (is_first_session)
      if !in_from_share_id.nil?
        request_uri = "#{request_uri}?tb=#{in_from_share_id}"
      end
      log_hashes << {:eventName => 'request', :userId => '', :timestamp => request_time, :service => 'service', :ip => ip_address, :referrer => referrer_uri, :requestUri => request_uri, :userAgent => user_agent, :fromShare => in_from_share_id}.merge(overrides)
      log_hashes << {:eventName => 'firstRequest', :userId => user_id, :timestamp => request_time, :service => 'service', :ip => ip_address, :referrer => referrer_uri, :requestUri => request_uri, :userAgent => user_agent, :fromShare => in_from_share_id}.merge(overrides)
    else
      log_hashes << {:eventName => 'request', :userId => user_id, :timestamp => request_time, :service => 'service', :ip => ip_address, :referrer => referrer_uri, :requestUri => request_uri, :userAgent => user_agent}.merge(overrides)
    end

    remaining_time = session_length
    while (remaining_time > 0)
      if remaining_time < 120 && rand(0) < 0.5
        time_to_next_request = remaining_time
      else
        time_to_next_request = rand([remaining_time, 900].min) + 1
      end
      referrer_uri = request_uri
      request_uri = "/randompage_#{rand(10)}"
      request_time += time_to_next_request
      remaining_time -= time_to_next_request
      log_hashes << {:eventName => 'request', :userId => user_id, :timestamp => request_time, :service => 'service', :ip => ip_address, :referrer => referrer_uri, :requestUri => request_uri, :userAgent => user_agent}.merge(overrides)
    end

    return log_hashes
  end

  def sessions(outfile)
    time_starts_at = Time.at(0)

    # session test: 4 users: one with three separate sessions; one with two sessions very close to each other; one with one session of nonzero length; one with one single-request/0-length session
    # share test: one user sharing two times, with no incoming users; one user sharing once, with two incoming users, one of which becomes a member; one user not sharing at all
    # metric/object test: two objects created, one object gets a measurement?
    # first session: one bot, one US user from google.com who become member, one user from an unknown source, one user from hatchery.cc
    # member status: three visitors; one becomes a member, one becomes a member and then a super_member

    # session test: 4 users: one with four separate sessions (with second including a measured event); one with two sessions very close to each other (with second including a measured event); one with one session of nonzero length; one with one single-request/0-length session

    log_hashes = []

    current_time = time_starts_at.to_i + rand(86400)
    user_id = "joe_active_four"
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000, true, nil, {:activityId => "#{current_time}#{user_id}"})
    log_hashes = log_hashes + become_member(user_id, current_time + 100, 'member', {:activityId => "#{current_time}#{user_id}"})
    current_time += 1000 + 900 + rand(86400)
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000, false, nil, {:activityId => "#{current_time}#{user_id}"})
    #log_hashes = log_hashes + measure_event(user_id, current_time + 10, 'great_measure')
    current_time += 1000 + 900 + rand(86400)
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000, false, nil, {:activityId => "#{current_time}#{user_id}"})
    current_time += 1000 + 900 + rand(86400)
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000, false, nil, {:activityId => "#{current_time}#{user_id}"})

    current_time = time_starts_at.to_i + rand(86400)
    user_id = "close_two"
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000, true, nil, {:activityId => "#{current_time}#{user_id}"})
    current_time += 1000 + 905
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000, false, nil, {:activityId => "#{current_time}#{user_id}"})
    #log_hashes = log_hashes + measure_event("close_two", current_time + 10, 'great_measure')

    current_time = time_starts_at.to_i + rand(86400)
    user_id = "just_once"
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000, true, nil, {:activityId => "#{current_time}#{user_id}"})

    current_time = time_starts_at.to_i + rand(86400)
    user_id = "bounce"
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 0, true, nil, {:activityId => "#{current_time}#{user_id}"})

    write_logs(outfile, log_hashes)
  end

  # share test: one user sharing two times, with no incoming users; one user sharing once, with two incoming users, one of whom becomes a member; those two users not sharing at all

  def shares(outfile)
    log_hashes = []
    time_starts_at = Time.at(0)

    user_id = "sad_sharer"
    current_time = time_starts_at.to_i + rand(86400)
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000, true)
    log_hashes = log_hashes + become_member(user_id, current_time + 100)
    log_hashes = log_hashes + log_share(user_id, current_time + 500, "share_by_#{user_id}")
    current_time += 1000 + 900 + rand(86400)
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000)
    log_hashes = log_hashes + log_share(user_id, current_time + 500, "second_share_by_#{user_id}")
    current_time += 1000 + 900 + rand(86400)
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000)
    current_time += 1000 + 900 + rand(86400)
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000)

    user_id = "effective_sharer"
    current_time = time_starts_at.to_i + rand(86400)
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000, true)
    effective_share_time = current_time + 500
    log_hashes = log_hashes + log_facebook_like(user_id, effective_share_time, "share_by_#{user_id}")
    current_time += 1000 + 905
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000)
    log_hashes = log_hashes + become_member(user_id, current_time + 100)

    user_id = "incoming_member"
    current_time = effective_share_time + rand(86400)
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000, true, "share_by_effective_sharer")
    log_hashes = log_hashes + become_member(user_id, current_time + 100)

    user_id = "incoming_invite_requested_member"
    current_time = effective_share_time + rand(86400)
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000, true, "share_by_effective_sharer")
    log_hashes = log_hashes + become_member(user_id, current_time + 100, 'invite_requested_member')

    user_id = "incoming_nonmember"
    current_time = effective_share_time + rand(86400)
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 0, true, "share_by_effective_sharer")



    write_logs(outfile, log_hashes)
  end



  # metric/object/timeline test: four objects created, one object gets a measurement once; one gets it on two different targets; one gets it twice on the same target

  def measure_me(outfile)
    log_hashes = []
    log_time = time_starts_at.to_i + 86400
    log_hashes << {:eventName => 'created', :objectType => 'my_object', :objectId => 'useless_object', :timestamp => log_time}

    log_time = time_starts_at.to_i + 86400*2
    log_hashes << {:eventName => 'created', :objectType => 'my_object', :objectId => 'once_object', :timestamp => log_time}
    log_time += 1000
    log_hashes << {:eventName => 'measureMe', :measureName => 'best_measure', :actorType => 'my_object', :actorId => 'once_object', :targetId => 'target', :timestamp => log_time}

    log_time = time_starts_at.to_i + 86400*3
    log_hashes << {:eventName => 'created', :objectType => 'my_object', :objectId => 'two_targets_object', :timestamp => log_time}
    log_time += 1000
    log_hashes << {:eventName => 'measureMe', :measureName => 'best_measure', :actorType => 'my_object', :actorId => 'two_targets_object', :targetId => 'target_one', :timestamp => log_time}
    log_time += 1000
    log_hashes << {:eventName => 'measureMe', :measureName => 'best_measure', :actorType => 'my_object', :actorId => 'two_targets_object', :targetId => 'target_two', :timestamp => log_time}

    log_time = time_starts_at.to_i + 86400*4
    log_hashes << {:eventName => 'created', :objectType => 'my_object', :objectId => 'twice_one_target_object', :timestamp => log_time}
    log_time += 1000
    log_hashes << {:eventName => 'measureMe', :measureName => 'best_measure', :actorType => 'my_object', :actorId => 'twice_one_target_object', :targetId => 'target_three', :timestamp => log_time}
    log_time += 1000
    log_hashes << {:eventName => 'measureMe', :measureName => 'best_measure', :actorType => 'my_object', :actorId => 'twice_one_target_object', :targetId => 'target_three', :timestamp => log_time}

    write_logs(outfile, log_hashes)
  end

  # first session/member: one bot, one user from google.com who become member, one user from an unknown source, one user from hatchery.cc

  def first_sessions(outfile)
    log_hashes = []

    user_id = "member_via_google"
    current_time = time_starts_at.to_i + rand(86400)
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000, true, nil, {:referrer => 'http://google.com'})
    log_hashes = log_hashes + become_member(user_id, current_time + 100)

    user_id = "eunknown"
    current_time = time_starts_at.to_i + rand(86400)
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000, true, nil, {:referrer => ''})

    user_id = "hatchery_references"
    current_time = time_starts_at.to_i + rand(86400)
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000, true, nil, {:referrer => 'http://hatchery.cc'})

    user_id = "bot"
    current_time = time_starts_at.to_i + rand(86400)
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 0, true, nil, {:userAgent => 'GoogleBot'})

    write_logs(outfile, log_hashes)
  end

  # member status: three visitors; one becomes a member, one becomes a member and then a super_member

  def member_status(outfile)
    log_hashes = []

    user_id = "super_member"
    current_time = time_starts_at.to_i + rand(86400)
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000, true)
    log_hashes = log_hashes + become_member(user_id, current_time + 100)
    current_time += 1000 + 900 + rand(86400)
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000)
    current_time += 1000 + 900 + rand(86400)
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000)
    log_hashes = log_hashes + become_member(user_id, current_time + 100, 'super_member')
    current_time += 1000 + 900 + rand(86400)
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000)

    user_id = "regular member"
    current_time = time_starts_at.to_i + rand(86400)
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000, true)
    log_hashes = log_hashes + become_member(user_id, current_time + 100)
    log_hashes = log_hashes + create_member(user_id, current_time + 100, 'Regular Joe', 'joe@test.com')
    current_time += 1000 + 905
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000)

    user_id = "non-member"
    current_time = time_starts_at.to_i + rand(86400)
    log_hashes = log_hashes + make_session_logs(user_id, current_time, 1000, true, "share_by_effective_sharer")

    write_logs(outfile, log_hashes)
  end
end

makeTestLogs = MakeTestLogs.new

file_types = [:sessions, :shares, :measure_me, :first_sessions, :member_status]

ARGV.each do |file_type|
  if file_types.include?(file_type.to_sym)
    outfile = File.expand_path("#{File.dirname(__FILE__)}/../test/log/#{file_type}.json")
    makeTestLogs.send(file_type, outfile)
  end
end

#
# # 1000 users, randomly (50/50) assigned to split test A or B
# # 5% from Grockit IP address; others from a completely random IP address
# # each comes to sample.com as firstRequest (so make a duplicate request with no user id)
# # 10% userAgent "bot", 90% "Chrome"
# # randomly pick a referrer from [facebook.com, google.com, somerandomsite.com]
# # group A has a 50% chance of just having initial request
# # group B has a 45% chance of just having initial request
# # if they don't just have the initial request, they have a random lifetime: uniform, 0-7*24*3600 seconds
# # 3 sessions per user (including first): one halfway, one at end
# #   each session has 3 requests: main page, two random pages (sample.com/<0-10>.html)), each with a 0-15s delay
# File.open(log_file, "w") do |file|
#   (1..100).each do |user_num|
#     ip_address = '206.169.112.34'
#     if (rand < 0.95)
#       ip_address = "#{rand(254)+1}.#{rand(254)+1}.#{rand(254)+1}.#{rand(254)+1}"
#     end
#
#     user_agent = 'Chrome'
#     if (rand < 0.10)
#       user_agent = 'Bot'
#     end
#
#     first_referrer = 'http://facebook.com'
#     ref_rand = rand
#     if (ref_rand < 0.25)
#       first_referrer = '/'
#     elsif (ref_rand < 0.6)
#       first_referrer = 'http://google.com'
#     elsif (ref_rand < 0.75)
#       first_referrer = 'http://somerandomsite.com'
#     end
#
#     # make first request (no user id)
#     first_request_at = Time.now.to_i + rand(86400*7)
#     file.puts("[service] " + {:eventName => 'request', :userId => '', :timestamp => first_request_at, :service => 'service', :ip => ip_address, :referrer => first_referrer, :requestUri => '/', :userAgent => user_agent}.to_json)
#     # make first request with user id
#     file.puts("[service] " + {:eventName => 'firstRequest', :userId => "user_#{user_num}", :timestamp => first_request_at, :service => 'service', :ip => ip_address, :referrer => first_referrer, :requestUri => '/', :userAgent => user_agent}.to_json)
#
#     # make split test
#     split_test = '0.50'
#     if (rand < 0.5)
#       split_test = '0.45'
#     end
#     file.puts("[service] " + {:eventName => 'splitTestAssignment', :experiment => 'test_experiment', :assignment => split_test, :userId => "user_#{user_num}", :timestamp => Time.now.to_i, :service => 'service'}.to_json)
#
#     # group A has a 50% chance of just having initial request
#     # group B has a 45% chance of just having initial request
#     if (rand > split_test.to_f)
#       # even if they only have the initial request, 20% of them become members
#       if rand < 0.2
#         file.puts("[service] " + {:eventName => 'membershipStatusChange', :userId => "user_#{user_num}", :timestamp => first_request_at + 2, :service => 'service', :newState => 'member'}.to_json)
#       end
#     else
#       # if they don't just have the initial request, they have a random lifetime: uniform, 0-7*24*3600 seconds
#       half_life = rand(7*24*3600/2)
#       # 3 sessions per user (including first): one halfway, one at end
#
#       (0..2).each do |session_num|
#         #   each session has 3 requests: main page, two random pages (sample.com/<0-10>.html)), each with a 0-15s delay
#         session_start = first_request_at + half_life * session_num
#         cur_request_time = session_start
#
#         file.puts("[service] " + {:eventName => 'request', :userId => "user_#{user_num}", :timestamp => cur_request_time, :service => 'service', :ip => ip_address, :referrer => '', :requestUri => '/', :userAgent => user_agent}.to_json)
#
#         # if they don't just have the initial request, they also become a member and create a thingy
#         if (session_num == 0)
#           cur_request_time = cur_request_time + rand(10)
#           file.puts("[service] " + {:eventName => 'membershipStatusChange', :userId => "user_#{user_num}", :timestamp => cur_request_time, :service => 'service', :newState => 'member'}.to_json)
#           file.puts("[service] " + {:eventName => 'measureMe', :userId => "user_#{user_num}", :timestamp => cur_request_time, :service => 'service', :measureName => 'create_object_thingy'}.to_json)
#           file.puts("[service] " + {:eventName => 'created', :userId => "user_#{user_num}", :timestamp => cur_request_time, :service => 'service', :objectType => 'thingy', :objectId => "object_of_user_#{user_num}"}.to_json)
#         end
#
#         (1..2).each do |request_num|
#           cur_request_time = cur_request_time + rand(16)
#           request_uri = rand(10)
#           file.puts("[service] " + {:eventName => 'request', :userId => "user_#{user_num}", :timestamp => cur_request_time, :service => 'service', :ip => ip_address, :referrer => '', :requestUri => "/page#{request_uri}.html", :userAgent => user_agent}.to_json)
#           # 0-2 random measureMe events per request
#           (1..rand(3)).each do |measure_num|
#             measure_name = "measure_#{rand(3)}"
#             measure_target = "target_#{rand(3)}"
#             file.puts("[service] " + {:eventName => 'measureMe', :userId => "user_#{user_num}", :timestamp => cur_request_time, :service => 'service', :measureName => measure_name, :measureTarget => measure_target, :measureAmount => 1}.to_json)
#           end
#           if rand < 0.4
#             file.puts("[service] " + {:eventName => 'measureMe', :userId => "user_#{user_num}", :timestamp => cur_request_time, :service => 'service', :measureName => 'twiddled_thingy', :measureTarget => "object_of_user_#{user_num}", :targetType => 'thingy', :measureAmount => 1}.to_json)
#           end
#         end
#       end
#     end
#   end
#   # make a future request, for session finishing's sake
#   file.puts("[service] " + {:eventName => 'request', :userId => 'fakeyfaker', :timestamp => (Time.new + 7*24*3600 + 1000).to_i, :service => 'service', :ip => '0.0.0.0', :referrer => '/', :requestUri => '/', :userAgent => ''}.to_json)
# end
