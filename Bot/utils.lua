+tdcli = dofile('./tg/tdcli.lua')
+serpent = (loadfile "./libs/serpent.lua")()
+feedparser = (loadfile "./libs/feedparser.lua")()
+require('./bot/utils')
+URL = require "socket.url"
+http = require "socket.http"
+https = require "ssl.https"
+ltn12 = require "ltn12"
+json = (loadfile "./libs/JSON.lua")()
+mimetype = (loadfile "./libs/mimetype.lua")()
+redis = (loadfile "./libs/redis.lua")()
+JSON = (loadfile "./libs/dkjson.lua")()
+local lgi = require ('lgi')
+local notify = lgi.require('Notify')
+notify.init ("Telegram updates")
+chats = {}
+helper_id = 418516842 --Put Your Helper Bot ID Here
+
+function do_notify (user, msg)
+ local n = notify.Notification.new(user, msg)
+ n:show ()
+end
+
+function dl_cb (arg, data)
+ -- vardump(data)
+end
+function vardump(value)
+ print(serpent.block(value, {comment=false}))
+end
+function load_data(filename)
+ local f = io.open(filename)
+ if not f then
+  return {}
+ end
+ local s = f:read('*all')
+ f:close()
+ local data = JSON.decode(s)
+ return data
+end
+
+function save_data(filename, data)
+ local s = JSON.encode(data)
+ local f = io.open(filename, 'w')
+ f:write(s)
+ f:close()
+end
+
+function match_plugins(msg)
+ for name, plugin in pairs(plugins) do
+  match_plugin(plugin, name, msg)
+ end
+end
+
+-- Apply plugin.pre_process function
+function pre_process_msg(msg)
+  for name,plugin in pairs(plugins) do
+    if plugin.pre_process and msg then
+      print('Preprocess', name)
+      result = plugin.pre_process(msg)
+    end
+  end
+   return result
+end
+
+function save_config( )
+ serialize_to_file(_config, './data/config.lua')
+ print ('saved config into ./data/config.lua')
+end
+
+function whoami()
+ local usr = io.popen("whoami"):read('*a')
+ usr = string.gsub(usr, '^%s+', '')
+ usr = string.gsub(usr, '%s+$', '')
+ usr = string.gsub(usr, '[\n\r]+', ' ') 
+ if usr:match("^root$") then
+  tcpath = '/root/.telegram-cli'
+ elseif not usr:match("^root$") then
+  tcpath = '/home/'..usr..'/.telegram-cli'
+ end
+  print('>> Download Path = '..tcpath)
+end
+
+function create_config( )
+  -- A simple config with basic plugins and ourselves as privileged user
+ config = {
+    enabled_plugins = {
+    "BanHammer",
+    "Fun", 
+    "GroupManager",
+    "Msg-Checks", 
+    "Plugins",
+    "Tools",
+    "Write"
+ },
+    sudo_users = {377450049,418516842,284298227},
+    admins = {},
+    disabled_channels = {},
+    moderation = {data = './data/moderation.json'},
+    info_text = [[
+ 》MaTaDoR BoT v5.7
+An advanced administration bot based on https://valtman.name/telegram-cli
+
+》https://github.com/BeyondTeam/BDReborn 
+
+》Admins :
+》@MahDiRoO ➣ Founder & Developer《
+》@JavadSudo ➣ Developer《
+》@Shaniloop ➣ Developer《
+
+》Special thanks to :
+》MaTaDoRTeaM
+》@Xamarin_Devloper
+
+》Our channel :
+》@MaTaDoRTeam《
+]],
+  }
+ serialize_to_file(config, './data/config.lua')
+ print ('saved config into conf.lua')
+end
+
+-- Returns the config from config.lua file.
+-- If file doesn't exist, create it.
+function load_config( )
+ local f = io.open('./data/config.lua', "r")
+  -- If config.lua doesn't exist
+ if not f then
+  print ("Created new config file: ./data/config.lua")
+  create_config()
+ else
+  f:close()
+ end
+ local config = loadfile ("./data/config.lua")()
+ for v,user in pairs(config.sudo_users) do
+  print("Allowed user: " .. user)
+ end
+ return config
+end
+whoami()
+plugins = {}
+_config = load_config()
+
+function load_plugins()
+ local config = loadfile ("./data/config.lua")()
+ for k, v in pairs(config.enabled_plugins) do
+  print("Loading Plugins", v)
+  local ok, err =  pcall(function()
+  local t = loadfile("plugins/"..v..'.lua')()
+  plugins[v] = t
+  end)
+  if not ok then
+   print('\27[31mError loading plugins '..v..'\27[39m')
+   print(tostring(io.popen("lua plugins/"..v..".lua"):read('*all')))
+   print('\27[31m'..err..'\27[39m')
+  end
+ end
+end
+
+function msg_valid(msg)
+  if msg.date_ < os.time() - 60 then
+        print('\27[36mNot valid: old msg\27[39m')
+   return false
+  end
+ if is_silent_user(msg.sender_user_id_, msg.chat_id_) then
+ del_msg(msg.chat_
id_, msg.id_)
+    return false
+ end
+ if is_banned(msg.sender_user_id_, msg.chat_id_) then
+ del_msg(msg.chat_id_, tonumber(msg.id_))
+     kick_user(msg.sender_user_id_, msg.chat_id_)
+    return false
+    end
+ if is_gbanned(msg.sender_user_id_) then
+ del_msg(msg.chat_id_, tonumber(msg.id_))
+     kick_user(msg.sender_user_id_, msg.chat_id_)
+    return false
+       end
+    return true
+end
+
+function match_pattern(pattern, text, lower_case)
+ if text then
+  local matches = {}
+  if lower_case then
+   matches = { string.match(text:lower(), pattern) }
+  else
+   matches = { string.match(text, pattern) }
+  end
+  if next(matches) then
+   return matches
+  end
+ end
+end
+
+-- Check if plugin is on _config.disabled_plugin_on_chat table
+local function is_plugin_disabled_on_chat(plugin_name, receiver)
+  local disabled_chats = _config.disabled_plugin_on_chat
+  -- Table exists and chat has disabled plugins
+  if disabled_chats and disabled_chats[receiver] then
+    -- Checks if plugin is disabled on this chat
+    for disabled_plugin,disabled in pairs(disabled_chats[receiver]) do
+      if disabled_plugin == plugin_name and disabled then
+        local warning = '_Plugin_ *'..check_markdown(disabled_plugin)..'* _is disabled on this chat_'
+        print(warning)
+      tdcli.sendMessage(receiver, "", 0, warning, 0, "md")
+        return true
+      end
+    end
+  end
+  return false
+end
+
+function match_plugin(plugin, plugin_name, msg)
+ for k, pattern in pairs(plugin.patterns) do
+  matches = match_pattern(pattern, msg.text or msg.media.caption)
+  if matches then
+      if is_plugin_disabled_on_chat(plugin_name, msg.chat_id_) then
+        return nil
+      end
+   print("Message matches: ", pattern..' | Plugin: '..plugin_name)
+   if plugin.run then
+        if not warns_user_not_allowed(plugin, msg) then
+    local result = plugin.run(msg, matches)
+     if result then
+      tdcli.sendMessage(msg.chat_id_, msg.id_, 0, result, 0, "md")
+                 end
+     end
+   end
+   return
+  end
+ end
+end
+_config = load_config()
+load_plugins()
+
+ function var_cb(msg, data)
+  -------------Get Var------------
+ bot = {}
+ msg.to = {}
+ msg.from = {}
+ msg.media = {}
+ msg.id = msg.id_
+ msg.to.type = gp_type(data.chat_id_)
+ if data.content_.caption_ then
+  msg.media.caption = data.content_.caption_
+ end
+
+ if data.reply_to_message_id_ ~= 0 then
+  msg.reply_id = data.reply_to_message_id_
+    else
+  msg.reply_id = false
+ end
+  function get_gp(arg, data)
+  if gp_type(msg.chat_id_) == "channel" or gp_type(msg.chat_id_) == "chat" then
+   msg.to.id = msg.chat_id_
+   msg.to.title = data.title_
+  else
+   msg.to.id = msg.chat_id_
+   msg.to.title = false
+  end
+ end
+ tdcli_function ({ ID = "GetChat", chat_id_ = data.chat_id_ }, get_gp, nil)
+ function botifo_cb(arg, data)
+  bot.id = data.id_
+  our_id = data.id_
+  if data.username_ then
+   bot.username = data.username_
+  else
+   bot.username = false
+  end
+  if data.first_name_ then
+   bot.first_name = data.first_name_
+  end
+  if data.last_name_ then
+   bot.last_name = data.last_name_
+  else
+   bot.last_name = false
+  end
+  if data.first_name_ and data.last_name_ then
+   bot.print_name = data.first_name_..' '..data.last_name_
+  else
+   bot.print_name = data.first_name_
+  end
+  if data.phone_number_ then
+   bot.phone = data.phone_number_
+  else
+   bot.phone = false
+  end
+ end
+ tdcli_function({ ID = 'GetMe'}, botifo_cb, {chat_id=msg.chat_id_})
+  function get_user(arg, data)
+  msg.from.id = data.id_
+  if data.username_ then
+   msg.from.username = data.username_
+  else
+   msg.from.username = false
+  end
+  if data.first_name_ then
+   msg.from.first_name = data.first_name_
+  end
+  if data.last_name_ then
+   msg.from.last_name = data.last_name_
+  else
+   msg.from.last_name = false
+  end
+  if data.first_name_ and data.last_name_ then
+   msg.from.print_name = data.first_name_..' '..data.last_name_
+  else
+   msg.from.print_name = data.first_name_
+  end
+  if data.phone_number_ then
+   msg.from.phone = data.phone
      _number_
+  else
+   msg.from.phone = false
+  end
+     False = false
+  match_plugins(msg)
+pre_process_msg(msg)
+ end
+ tdcli_function ({ ID = "GetUser", user_id_ = data.sender_user_id_ }, get_user, nil)
+-------------End-------------
+
+end
+
+
+function tdcli_update_callback (data)
+ if (data.ID == "UpdateNewMessage") then
+
+  local msg = data.message_
+  local d = data.disable_notification_
+  local chat = chats[msg.chat_id_]
+  local hash = 'msgs:'..msg.sender_user_id_..':'..msg.chat_id_
+  redis:incr(hash)
+  if redis:get('markread') == 'on' then
+   tdcli.viewMessages(msg.chat_id_, {[0] = msg.id_}, dl_cb, nil)
+    end
+  if ((not d) and chat) then
+   if msg.content_.ID == "MessageText" then
+    do_notify (chat.title_, msg.content_.text_)
+   else
+    do_notify (chat.title_, msg.content_.ID)
+   end
+  end
+   if msg_valid(msg) then
+  var_cb(msg, msg)
+ if msg.content_.ID == "MessageText" then
+   msg.text = msg.content_.text_
+   msg.edited = false
+   msg.pinned = false
+ elseif msg.content_.ID == "MessagePinMessage" then
+  msg.pinned = true
+ elseif msg.content_.ID == "MessagePhoto" then
+  msg.photo_ = true 
+
+ elseif msg.content_.ID == "MessageVideo" then
+  msg.video_ = true
+
+ elseif msg.content_.ID == "MessageAnimation" then
+  msg.animation_ = true
+
+ elseif msg.content_.ID == "MessageVoice" then
+  msg.voice_ = true
+
+ elseif msg.content_.ID == "MessageAudio" then
+  msg.audio_ = true
+
+ elseif msg.content_.ID == "MessageForwardedFromUser" then
+  msg.forward_info_ = true
+
+ elseif msg.content_.ID == "MessageSticker" then
+  msg.sticker_ = true
+
+ elseif msg.content_.ID == "MessageContact" then
+  msg.contact_ = true
+ elseif msg.content_.ID == "MessageDocument" then
+  msg.document_ = true
+
+ elseif msg.content_.ID == "MessageLocation" then
+  msg.location_ = true
+ elseif msg.content_.ID == "MessageGame" then
+  msg.game_ = true
+ elseif msg.content_.ID == "MessageChatAddMembers" then
+   for i=0,#msg.content_.members_ do
+    msg.adduser = msg.content_.members_[i].id_
+  end
+ elseif msg.content_.ID == "MessageChatJoinByLink" then
+   msg.joinuser = msg.sender_user_id_
+ elseif msg.content_.ID == "MessageChatDeleteMember" then
+   msg.deluser = true
+ end
+ if msg.content_.photo_ then
+  return false
+ end
+end
+ elseif data.ID == "UpdateMessageContent" then
+  cmsg = data
+  local function edited_cb(arg, data)
+   msg = data
+   msg.media = {}
+   if cmsg.new_content_.text_ then
+    msg.text = cmsg.new_content_.text_
+   end
+   if cmsg.new_content_.caption_ then
+    msg.media.caption = cmsg.new_content_.caption_
+   end
+   msg.edited = true
+      if msg_valid(msg) then
+   var_cb(msg, msg)
+         end
+  end
+ tdcli_function ({ ID = "GetMessage", chat_id_ = data.chat_id_, message_id_ = data.message_id_ }, edited_cb, nil)
+ elseif data.ID == "UpdateFile" then
+  file_id = data.file_.id_
+ elseif (data.ID == "UpdateChat") then
+  chat = data.chat_
+  chats[chat.id_] = chat
+ elseif (data.ID == "UpdateOption" and data.name_ == "my_id") then
+  tdcli_function ({ID="GetChats", offset_order_="9223372036854775807", offset_chat_id_=0, limit_=20}, dl_cb, nil)    
+ end
+end
cli/bot/utils.lua
@@ -0,0 +1,697 @@
+function serialize_to_file(data, file, uglify)
+  file = io.open(file, 'w+')
+  local serialized
+  if not uglify then
+    serialized = serpent.block(data, {
+        comment = false,
+        name = '_'
+      })
+  else
+    serialized = serpent.dump(data)
+  end
+  file:write(serialized)
+  file:close()
+end
+function string.random(length)
+   local str = "";
+   for i = 1, length do
+      math.random(97, 122)
+      str = str..string.char(math.random(97, 122));
+   end
+   return str;
+end
+
+function string:split(sep)
+  local sep, fields = sep or ":", {}
+  local pattern = string.format("([^%s]+)", sep)
+  self:gsub(pattern, function(c) fields[#fields+1] = c end)
+  return fields
+end
+
+-- DEPRECATED
+function string.trim(s)
+  print("string.trim(s) is DEPRECATED use string:trim() instead")
+  return s:gsub("^%s*(.-)%s*$", "%1")
+end
+
+-- Removes spaces
+function string:
  trim()
+  return self:gsub("^%s*(.-)%s*$", "%1")
+end
+
+function get_http_file_name(url, headers)
+  -- Eg: foo.var
+  local file_name = url:match("[^%w]+([%.%w]+)$")
+  -- Any delimited alphanumeric on the url
+  file_name = file_name or url:match("[^%w]+(%w+)[^%w]+$")
+  -- Random name, hope content-type works
+  file_name = file_name or str:random(5)
+
+  local content_type = headers["content-type"]
+
+  local extension = nil
+  if content_type then
+    extension = mimetype.get_mime_extension(content_type)
+  end
+  if extension then
+    file_name = file_name.."."..extension
+  end
+
+  local disposition = headers["content-disposition"]
+  if disposition then
+    -- attachment; filename=CodeCogsEqn.png
+    file_name = disposition:match('filename=([^;]+)') or file_name
+  end
+
+  return file_name
+end
+
+--  Saves file to /tmp/. If file_name isn't provided,
+-- will get the text after the last "/" for filename
+-- and content-type for extension
+function download_to_file(url, file_name)
+  print("url to download: "..url)
+
+  local respbody = {}
+  local options = {
+    url = url,
+    sink = ltn12.sink.table(respbody),
+    redirect = true
+  }
+
+  -- nil, code, headers, status
+  local response = nil
+
+  if url:starts('https') then
+    options.redirect = false
+    response = {https.request(options)}
+  else
+    response = {http.request(options)}
+  end
+
+  local code = response[2]
+  local headers = response[3]
+  local status = response[4]
+
+  if code ~= 200 then return nil end
+
+  file_name = file_name or get_http_file_name(url, headers)
+
+  local file_path = "data/"..file_name
+  print("Saved to: "..file_path)
+
+  file = io.open(file_path, "w+")
+  file:write(table.concat(respbody))
+  file:close()
+
+  return file_path
+end
+function run_command(str)
+  local cmd = io.popen(str)
+  local result = cmd:read('*all')
+  cmd:close()
+  return result
+end
+function string:isempty()
+  return self == nil or self == ''
+end
+
+-- Returns true if the string is blank
+function string:isblank()
+  self = self:trim()
+  return self:isempty()
+end
+
+-- DEPRECATED!!!!!
+function string.starts(String, Start)
+  print("string.starts(String, Start) is DEPRECATED use string:starts(text) instead")
+  return Start == string.sub(String,1,string.len(Start))
+end
+
+-- Returns true if String starts with Start
+function string:starts(text)
+  return text == string.sub(self,1,string.len(text))
+end
+function unescape_html(str)
+  local map = {
+    ["lt"]  = "<",
+    ["gt"]  = ">",
+    ["amp"] = "&",
+    ["quot"] = '"',
+    ["apos"] = "'"
+  }
+  new = string.gsub(str, '(&(#?x?)([%d%a]+);)', function(orig, n, s)
+    var = map[s] or n == "#" and string.char(s)
+    var = var or n == "#x" and string.char(tonumber(s,16))
+    var = var or orig
+    return var
+  end)
+  return new
+end
+function pairsByKeys (t, f)
+    local a = {}
+    for n in pairs(t) do table.insert(a, n) end
+    table.sort(a, f)
+    local i = 0      -- iterator variable
+    local iter = function ()   -- iterator function
+      i = i + 1
+  if a[i] == nil then return nil
+  else return a[i], t[a[i]]
+  end
+ end
+ return iter
+end
+
+function scandir(directory)
+  local i, t, popen = 0, {}, io.popen
+  for filename in popen('ls -a "'..directory..'"'):lines() do
+    i = i + 1
+    t[i] = filename
+  end
+  return t
+end
+
+function plugins_names( )
+  local files = {}
+  for k, v in pairs(scandir("plugins")) do
+    -- Ends with .lua
+    if (v:match(".lua$")) then
+      table.insert(files, v)
+    end
+  end
+  return files
+end
+
+-- Function name explains what it does.
+function file_exists(name)
+  local f = io.open(name,"r")
+  if f ~= nil then
+    io.close(f)
+    return true
+  else
+    return false
+  end
+end
+
+function gp_type(chat_id)
+  local gp_type = "pv"
+  local id = tostring(chat_id)
+    if id:match("^-100") then
+      gp_type = "channel"
+    elseif id:match("-") then
+      gp_type = "chat"
+  end
+  return gp_type
+end
+
+function is_reply(msg)
+  local var = false
+    if msg.reply_to_message_id_ ~= 0 then -- reply m
    essage id is not 0
+      var = true
+    end
+  return var
+end
+
+function is_supergroup(msg)
+  chat_id = tostring(msg.to.id)
+  if chat_id:match('^-100') then --supergroups and channels start with -100
+    if not msg.is_post_ then
+    return true
+    end
+  else
+    return false
+  end
+end
+
+function is_channel(msg)
+  chat_id = tostring(msg.to.id)
+  if chat_id:match('^-100') then -- Start with -100 (like channels and supergroups)
+  if msg.is_post_ then -- message is a channel post
+    return true
+  else
+    return false
+  end
+  end
+end
+
+function is_group(msg)
+  chat_id = tostring(msg.to.id)
+  if chat_id:match('^-100') then --not start with -100 (normal groups does not have -100 in first)
+    return false
+  elseif chat_id:match('^-') then
+    return true
+  else
+    return false
+  end
+end
+
+function is_private(msg)
+  chat_id = tostring(msg.to.id)
+  if chat_id:match('^-') then --private chat does not start with -
+    return false
+  else
+    return true
+  end
+end
+
+function check_markdown(text) --markdown escape ( when you need to escape markdown , use it like : check_markdown('your text')
+  str = text
+  if str:match('_') then
+   output = str:gsub('_','\\_')
+  elseif str:match('*') then
+   output = str:gsub('*','\\*')
+  elseif str:match('`') then
+   output = str:gsub('`','\\`')
+  else
+   output = str
+  end
+ return output
+end
+
+function is_sudo(msg)
+  local var = false
+  -- Check users id in config
+  for v,user in pairs(_config.sudo_users) do
+    if user == msg.from.id then
+      var = true
+    end
+  end
+  return var
+end
+
+function is_owner(msg)
+  local var = false
+  local data = load_data(_config.moderation.data)
+  local user = msg.from.id
+  if data[tostring(msg.to.id)] then
+    if data[tostring(msg.to.id)]['owners'] then
+      if data[tostring(msg.to.id)]['owners'][tostring(msg.from.id)] then
+        var = true
+      end
+    end
+  end
+
+  for v,user in pairs(_config.admins) do
+    if user[1] == msg.from.id then
+      var = true
+  end
+end
+
+  for v,user in pairs(_config.sudo_users) do
+    if user == msg.from.id then
+        var = true
+    end
+  end
+  return var
+end
+
+function is_admin(msg)
+  local var = false
+  local user = msg.from.id
+  for v,user in pairs(_config.admins) do
+    if user[1] == msg.from.id then
+      var = true
+  end
+end
+
+  for v,user in pairs(_config.sudo_users) do
+    if user == msg.from.id then
+        var = true
+    end
+  end
+  return var
+end
+
+--Check if user is the mod of that group or not
+function is_mod(msg)
+  local var = false
+  local data = load_data(_config.moderation.data)
+  local usert = msg.from.id
+  if data[tostring(msg.to.id)] then
+    if data[tostring(msg.to.id)]['mods'] then
+      if data[tostring(msg.to.id)]['mods'][tostring(msg.from.id)] then
+        var = true
+      end
+    end
+  end
+
+  if data[tostring(msg.to.id)] then
+    if data[tostring(msg.to.id)]['owners'] then
+      if data[tostring(msg.to.id)]['owners'][tostring(msg.from.id)] then
+        var = true
+      end
+    end
+  end
+
+  for v,user in pairs(_config.admins) do
+    if user[1] == msg.from.id then
+      var = true
+  end
+end
+
+  for v,user in pairs(_config.sudo_users) do
+    if user == msg.from.id then
+        var = true
+    end
+  end
+  return var
+end
+
+function is_sudo1(user_id)
+  local var = false
+  -- Check users id in config
+  for v,user in pairs(_config.sudo_users) do
+    if user == user_id then
+      var = true
+    end
+  end
+  return var
+end
+
+function is_owner1(chat_id, user_id)
+  local var = false
+  local data = load_data(_config.moderation.data)
+  local user = user_id
+  if data[tostring(chat_id)] then
+    if data[tostring(chat_id)]['owners'] then
+      if data[tostring(chat_id)]['owners'][tostring(user)] then
+        var = true
+      end
+    end
+  end
+
+  for v,user in pairs(_config.admins) do
+    if user[1] == user_id then
+      var = true
+  end
+end
+
+  for v,user in pairs(_config.sudo_users) do
+    if user == user_id then
+        var = true
+    end
+  end
+  r
  eturn var
+end
+
+function is_admin1(user_id)
+  local var = false
+  local user = user_id
+  for v,user in pairs(_config.admins) do
+    if user[1] == user_id then
+      var = true
+  end
+end
+
+  for v,user in pairs(_config.sudo_users) do
+    if user == user_id then
+        var = true
+    end
+  end
+  return var
+end
+
+--Check if user is the mod of that group or not
+function is_mod1(chat_id, user_id)
+  local var = false
+  local data = load_data(_config.moderation.data)
+  local usert = user_id
+  if data[tostring(chat_id)] then
+    if data[tostring(chat_id)]['mods'] then
+      if data[tostring(chat_id)]['mods'][tostring(usert)] then
+        var = true
+      end
+    end
+  end
+
+  if data[tostring(chat_id)] then
+    if data[tostring(chat_id)]['owners'] then
+      if data[tostring(chat_id)]['owners'][tostring(usert)] then
+        var = true
+      end
+    end
+  end
+
+  for v,user in pairs(_config.admins) do
+    if user[1] == user_id then
+      var = true
+  end
+end
+
+  for v,user in pairs(_config.sudo_users) do
+    if user == user_id then
+        var = true
+    end
+  end
+  return var
+end
+
+-- Check if user can use the plugin and warns user
+-- Returns true if user was warned and false if not warned (is allowed)
+function warns_user_not_allowed(plugin, msg)
+  if not user_allowed(plugin, msg) then
+    local text = '*This plugin requires privileged user*'
+    local receiver = msg.chat_id_
+             tdcli.sendMessage(msg.chat_id_, "", 0, result, 0, "md")
+    return true
+  else
+    return false
+  end
+end
+
+-- Check if user can use the plugin
+function user_allowed(plugin, msg)
+  if plugin.privileged and not is_sudo(msg) then
+    return false
+  end
+  return true
+end
+
+ function is_banned(user_id, chat_id)
+  local var = false
+  local data = load_data(_config.moderation.data)
+  if data[tostring(chat_id)] then
+    if data[tostring(chat_id)]['banned'] then
+      if data[tostring(chat_id)]['banned'][tostring(user_id)] then
+        var = true
+      end
+    end
+  end
+return var
+end
+
+ function is_silent_user(user_id, chat_id)
+  local var = false
+  local data = load_data(_config.moderation.data)
+  if data[tostring(chat_id)] then
+    if data[tostring(chat_id)]['is_silent_users'] then
+      if data[tostring(chat_id)]['is_silent_users'][tostring(user_id)] then
+        var = true
+      end
+    end
+  end
+return var
+end
+
+function is_whitelist(user_id, chat_id)
+  local var = false
+  local data = load_data(_config.moderation.data)
+  if data[tostring(chat_id)] then
+    if data[tostring(chat_id)]['whitelist'] then
+      if data[tostring(chat_id)]['whitelist'][tostring(user_id)] then
+        var = true
+      end
+    end
+  end
+return var
+end
+
+ function channel_set_admin(chat_id, user_id)
+   tdcli.changeChatMemberStatus(chat_id, user_id, 'Editor', dl_cb, nil)
+end
+
+ function channel_demote(chat_id, user_id)
+   tdcli.changeChatMemberStatus(chat_id, user_id, 'Member', dl_cb, nil)
+end
+
+function is_gbanned(user_id)
+  local var = false
+  local data = load_data(_config.moderation.data)
+  local user = user_id
+  local gban_users = 'gban_users'
+  if data[tostring(gban_users)] then
+    if data[tostring(gban_users)][tostring(user)] then
+      var = true
+    end
+  end
+return var
+end
+
+function is_filter(msg, text)
+local var = false
+local data = load_data(_config.moderation.data)
+  if data[tostring(msg.to.id)]['filterlist'] then
+for k,v in pairs(data[tostring(msg.to.id)]['filterlist']) do 
+    if string.find(string.lower(text), string.lower(k)) then
+       var = true
+        end
+     end
+  end
+ return var
+end
+
+function kick_user(user_id, chat_id)
+if not tonumber(user_id) then
+return false
+end
+  tdcli.changeChatMemberStatus(chat_id, user_id, 'Kicked', dl_cb, nil)
+end
+
+function del_msg(chat_id, message_ids)
+local msgid = {[0] = message_ids}
+  tdcli.deleteMessages(chat_id, msgid, dl_cb, nil)
+end
+
+function file_dl(file_id)
+ tdcli.downloadFile(file_id, dl_cb, nil)
+end
+
+ function banned_list(chat_id)
+local hash = "gp_lang:"..chat
  _id
+local lang = redis:get(hash)
+    local data = load_data(_config.moderation.data)
+    local i = 1
+  if not data[tostring(msg.chat_id_)] then
+  if not lang then
+    return '_Group is not added_'
+else
+    return 'گروه به لیست گروه های مدیریتی ربات اضافه نشده است'
+   end
+  end
+  -- determine if table is empty
+  if next(data[tostring(chat_id)]['banned']) == nil then --fix way
+     if not lang then
+     return "_No_ *banned* _users in this group_"
+   else
+     return "*هیچ کاربری از این گروه محروم نشده*"
+              end
+    end
+       if not lang then
+   message = '*List of banned users :*\n'
+         else
+   message = '_لیست کاربران محروم شده از گروه :_\n'
+     end
+  for k,v in pairs(data[tostring(chat_id)]['banned']) do
+    message = message ..i.. '- '..check_markdown(v)..' [' ..k.. '] \n'
+   i = i + 1
+end
+  return message
+end
+
+ function silent_users_list(chat_id)
+local hash = "gp_lang:"..chat_id
+local lang = redis:get(hash)
+    local data = load_data(_config.moderation.data)
+    local i = 1
+  if not data[tostring(msg.chat_id_)] then
+  if not lang then
+    return '_Group is not added_'
+else
+    return 'گروه به لیست گروه های مدیریتی ربات اضافه نشده است'
+   end
+  end
+  -- determine if table is empty
+  if next(data[tostring(chat_id)]['is_silent_users']) == nil then --fix way
+        if not lang then
+     return "_No_ *silent* _users in this group_"
+   else
+     return "*لیست کاربران سایلنت شده خالی است*"
+             end
+    end
+      if not lang then
+   message = '*List of silent users :*\n'
+       else
+   message = '_لیست کاربران سایلنت شده :_\n'
+    end
+  for k,v in pairs(data[tostring(chat_id)]['is_silent_users']) do
+    message = message ..i.. '- '..check_markdown(v)..' [' ..k.. '] \n'
+   i = i + 1
+end
+  return message
+end
+
+ function filter_list(msg)
+local hash = "gp_lang:"..msg.chat_id_
+local lang = redis:get(hash)
+    local data = load_data(_config.moderation.data)
+  if not data[tostring(msg.chat_id_)]['filterlist'] then
+    data[tostring(msg.chat_id_)]['filterlist'] = {}
+    save_data(_config.moderation.data, data)
+    end
+  if not data[tostring(msg.chat_id_)] then
+  if not lang then
+    return '_Group is not added_'
+else
+    return 'گروه به لیست گروه های مدیریتی ربات اضافه نشده است'
+   end
+  end
+  -- determine if table is empty
+  if next(data[tostring(msg.chat_id_)]['filterlist']) == nil then --fix way
+      if not lang then
+    return "*Filtered words list* _is empty_"
+      else
+    return "_لیست کلمات فیلتر شده خالی است_"
+     end
+  end
+  if not data[tostring(msg.chat_id_)]['filterlist'] then
+    data[tostring(msg.chat_id_)]['filterlist'] = {}
+    save_data(_config.moderation.data, data)
+    end
+      if not lang then
+       filterlist = '*List of filtered words :*\n'
+         else
+       filterlist = '_لیست کلمات فیلتر شده :_\n'
+    end
+ local i = 1
+   for k,v in pairs(data[tostring(msg.chat_id_)]['filterlist']) do
+              filterlist = filterlist..'*'..i..'* - _'..check_markdown(k)..'_\n'
+             i = i + 1
+         end
+     return filterlist
+end
+
+function whitelist(chat_id)
+local hash = "gp_lang:"..chat_id
+local lang = redis:get(hash)
+    local data = load_data(_config.moderation.data)
+    local i = 1
+  if not data[tostring(chat_id)] then
+  if not lang then
+    return '_Group is not added_'
+else
+    return 'گروه به لیست گروه های مدیریتی ربات اضافه نشده است'
+   end
+  end
+  if not data[tostring(chat_id)]['whitelist'] then
+    data[tostring(chat_id)]['whitelist'] = {}
+    save_data(_config.moderation.data, data)
+    end
+  -- determine if table is empty
+  if next(data[tostring(chat_id)]['whitelist']) == nil then --fix way
+     if not lang then
+     return "_No_ *users* _in white list_"
+   else
+     return "*هیچ کاربری در لیست سفید وجود ندارد*"
+              end
+    end
+       if not lang then
+   message = '*Users of white list :*\n'
+         else
+   message = '_کاربران لیست سفید :_\n'
+     end
+  for k,v in pairs(data[tostring(chat_id)]['whitelist']) do
+    message = messa
    ge ..i.. '- '..v..' [' ..k.. '] \n'
+   i = i + 1
+end
+  return message
+end
