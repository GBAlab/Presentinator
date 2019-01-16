% input: txt = string to log
%        logFid  = log file id
%        ip/port = network address to where    
%        verbose = verbosity level: 3=debug

lastCommandScreen = sprintf('DONE @ %s %s', datestr(now), strrep(txt,sprintf('\n'),'\n'));

if logFid ~= -1 && verbose > 2
   fprintf(logFid, '%s  %%%s\n', lastcommand, lastCommandScreen); 
   lastcommand = '';
end
if port % if port == 0 it was keyboard event
    pnet(udp,'write', lastCommandScreen);     
    pnet(udp,'writepacket',ip,port);   % Send buffer as UDP packet
end

lastCommandScreen = sprintf('DONE @ %s %s by %s', datestr(now), strtok(txt,sprintf('\n')), cmd_sender);

if logFid == -1 && verbose > 2
    disp(lastCommandScreen);
end
