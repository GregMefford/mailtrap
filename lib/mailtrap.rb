require 'socket'

#
# Mailtrap creates a TCP server that listens on a specified port for SMTP
# clients. Accepts the connection and talks just enough of the SMTP protocol
# for them to deliver a message
#
# Stripped down to be a simple command-line script by Greg Mefford
class Mailtrap
  
  # Create a new Mailtrap on the specified host:port. 
  def initialize( host, port )
    @host = host
    @port = port
    
    puts "\n* Mailtrap started at #{@host}:#{port}\n"
    
    service = TCPServer.new( @host, @port )
    accept( service )
  end
  
  # Service one or more SMTP client connections
  def accept( service )
    while session = service.accept
      
      class << session
        def get_line
          line = gets
          line.chomp! unless line.nil?
          line          
        end
      end
      
      begin
        serve( session )
      rescue Exception => e
        puts "Error: #{e.message}"        
      end
    end    
  end
  
  # Plain text dump of the incoming email
  def handle_message( from, to_list, message )
    # Strip SMTP commands from To: and From:
    from.gsub!( /MAIL FROM:\s*/, "" )
    to_list = to_list.map { |to| to.gsub( /RCPT TO:\s*/, "" ) }

    puts "* Message begins"
    puts "  From: #{from}"
    puts "  To: #{to_list.join(", ")}"
    puts "  Body:"
    puts message
    puts "\n* Message ends"

  end
  
  # Talk enough SMTP to get the message from the client
  def serve( connection )
    connection.puts( "220 #{@host} MailTrap ready ESTMP" )
    helo = connection.get_line # whoever they are
    puts "Helo: #{helo}"
    
    if helo =~ /^EHLO\s+/
      puts "Seen an EHLO"
      connection.puts "250-#{@host}"
      connection.puts "250 HELP"
    end
    
    # Accept MAIL FROM:
    from = connection.get_line
    connection.puts( "250 OK" )
    puts "From: #{from}"
    
    to_list = []
    
    # Accept RCPT TO: until we see DATA
    loop do
      to = connection.get_line
      break if to.nil?

      if to =~ /^DATA/
        connection.puts( "354 Start your message" )
        break
      else
        puts "To: #{to}"
        to_list << to
        connection.puts( "250 OK" )
      end
    end
    
    # Capture the message body terminated by <CR>.<CR>
    lines = []
    loop do
      line = connection.get_line
      break if line.nil? || line == "."
      lines << line
      puts "+ #{line}"
    end

    # We expect the client will go away now
    connection.puts( "250 OK" )
    connection.gets # Quit
    connection.puts "221 Seeya"
    connection.close
    puts "===================================="

    handle_message( from, to_list, lines.join( "\n" ) )
    
  end
end

server = Mailtrap.new( '0.0.0.0', 25 )