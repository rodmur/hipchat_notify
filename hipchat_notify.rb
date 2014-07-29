#!/usr/bin/ruby
require 'rubygems'
require 'hipchat-api'
require 'getopt/long'
require 'socket'
require 'erb'
 
#Do not modify these constants! (after you set these up, of course)
#HipApiKey='ABCDEFGHKJHKJHKJHKJH'
HipApiKey='XXXXXXXXXXX'
Room='Some Room'
# green room
GreenRoomID=542071
# red room
RedRoomID=584139
# testing room
TestRoomID=542730
FromID='Icinga'
###
Colors={
        'PROBLEM'=>'red',
        'RECOVERY'=>'green',
        'ACKNOWLEDGEMENT'=>'green',
        'FLAPPINGSTART'=>'purple',
        'FLAPPINGSTOP'=>'green',
        'FLAPPINGDISABLED'=>'gray',
        'DOWNTIMESTART'=>'red',
        'DOWNTIMESTOP'=>'green',
        'DOWNTIMECANCELLED'=>'green'
        }
 
#ERB templates for message format
$types={
'host'=>
        %q{
<%= @timestamp %> - Host <%= @hostname %>  (Origin: nagios@<%= @nagioshost %>)
Details:
        Notification type: <%= @type %>
        Host: <%= @hostname %> (Address <%= @hostaddress %>)
        State: <%= @hoststate %>
        Info:
        <%= @hostoutput %>
---------
}.gsub(/\n/,'<br>'),
 
'service'=>
        %q{
<%= @timestamp %> - Service <%= @servicedesc %> on Host <%= @hostalias %> (Origin: nagios@<%= @nagioshost %>)
Details:
        Notification type: <%= @type %>
        Host: <%= @hostalias %> (Address <%= @hostaddress %>)
        State: <%= @servicestate %>
        Info:
        <%= @serviceoutput %>
--------
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
	if @type == 'PROBLEM'
#		RoomID = RedRoomID
		RoomID = TestRoomID
	else
#		RoomID = GreenRoomID
		RoomID = TestRoomID
	end
elsif ($opts['type'] == 'service')
        @nagioshost=Socket.gethostname.split('.')[0]
        @servicedesc,@hostalias,@timestamp,@type,@hostaddress,@servicestate,@serviceoutput = $opts['inputs'].split('|')
        msg=ERB.new($types[ $opts['type'] ]).result()
	if @type == 'PROBLEM'
#		RoomID = RedRoomID
		RoomID = TestRoomID
		if @servicestate == 'WARNING'
			whichcolor = 'yellow'
		elsif @servicestate == 'CRITICAL'
			whichcolor = 'red'
		end
	else
#		RoomID = GreenRoomID
		RoomID = TestRoomID
        	whichcolor=Colors[@type] || 'gray'
	end
end
 
conn=nil
begin
        conn=HipChat::API.new(HipApiKey)
rescue Exception => e
        $stderr.puts "Error connecting to HipChat: "+e.inspect
        exit
end
 
conn.rooms_message(RoomID,FromID,msg,notify = $opts['notify'],color= whichcolor)
