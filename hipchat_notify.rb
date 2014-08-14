#!/usr/bin/ruby
require 'rubygems'
require 'hipchat-api'
require 'getopt/long'
require 'socket'
require 'erb'
require 'yaml'

FILENAME='/usr/local/etc/hipchat_notify.yaml'
data = YAML::load(File.open(FILENAME))
 
HipToken=data["token"]
RoomID=data["roomid"]
FromID=data["from"]
Colors=data["colors"]
 
#ERB templates for message format
$types={
'host'=>
        %q{ <%= @timestamp %> - Origin: nagios@<%= @nagioshost %>
Notification type: <%= @type %>
Host: <%= @hostname %> (Address <%= @hostaddress %>)
<%= @hostoutput %>
}.gsub(/\n/,'<br>'),
 
'service'=>
        %q{ <%= @timestamp %> - Origin: nagios@<%= @nagioshost %>
Notification type: <%= @type %>
Host: <%= @hostalias %> (Address <%= @hostaddress %>)
<%= @serviceoutput %>
}.gsub(/\n/,'<br>')
}
 
#Locate room id. - save time - use previously located id
def getroomid(hipconn,roomname)
roomid=nil
roomid if hipconn.nil? || roomname.nil?
hipconn.rooms_list['rooms'].each do |thisroom|
        roomid=thisroom['room_id'] if thisroom['name'] == roomname
end
roomid
end
 
def getuserid(hipconn,username)
userid=nil
hipconn.users_list['users'].each do |thisuser|
        userid=thisuser['user_id'] if thisuser['name']==username
end
userid
end
#'$SERVICESTATE$|$STATETYPE$|$HOSTSTATE$|$SERVICEDESC$|$OUTPUT$|$SHORTDATETIME$|$HOSTNAME$'
 
$opts=Getopt::Long.getopts(
["--type","-t",Getopt::REQUIRED],
["--inputs","-i",Getopt::REQUIRED],
["--notify","-n",Getopt::BOOLEAN]
)
 
if(! $types.has_key?( $opts['type'] ) )
        $stderr.puts "Unknown notification type: #{$opts['type']}!"
        exit
end
msg=nil
whichcolor='gray'
if($opts['type'] == 'host')
        @nagioshost=Socket.gethostname.split('.')[0]
        @hostname,@timestamp,@type,@hostaddress,@hoststate,@hostoutput = $opts['inputs'].split('|')
        msg=ERB.new($types[ $opts['type']  ]).result()
        whichcolor=Colors[@type] || 'gray'
elsif ($opts['type'] == 'service')
        @nagioshost=Socket.gethostname.split('.')[0]
        @servicedesc,@hostalias,@timestamp,@type,@hostaddress,@servicestate,@serviceoutput = $opts['inputs'].split('|')
        msg=ERB.new($types[ $opts['type'] ]).result()
	if @type == 'PROBLEM'
		if @servicestate == 'WARNING'
			whichcolor = 'yellow'
		elsif @servicestate == 'CRITICAL'
			whichcolor = 'red'
		end
	else
        	whichcolor=Colors[@type] || 'gray'
	end
end
 
conn=nil
begin
        conn=HipChat::API.new(HipToken)
rescue Exception => e
        $stderr.puts "Error connecting to HipChat: "+e.inspect
        exit
end
 
conn.rooms_message(RoomID,FromID,msg,notify = $opts['notify'],color= whichcolor)
