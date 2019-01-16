% input: txt = string to log
%        logFid  = log file id
%        ip/port = network address to where    
%        verbose = verbosity level: 3=debug

lastCommandScreen = sprintf('ERROR @ %s %s ', datestr(now), strrep(txt,sprintf('\n'),'\n'));
if (logFid ~= -1)
    fprintf(logFid, '%s %%%s\n', lastcommand, lastCommandScreen); 
    lastcommand = '';
end

if port % if port == 0 it was keyboard event
    pnet(udp,'write', lastCommandScreen);     
    pnet(udp,'writepacket',ip,port);   % Send buffer as UDP packet
end

lastCommandScreen = sprintf('ERROR @ %s %s by %s', datestr(now), strtok(txt,sprintf('\n')), cmd_sender);
try %maybe there is no window anymore
    if verbose || logFid == -1
        Screen('CopyWindow',scrBg,w);
        Screen(w,'DrawText', lastCommandScreen, 20, 40, txtcolor);
    end

    if verbose > 2
        Screen(w,'DrawText', 'Press any key to continue!', 200, 60, txtcolor);
        while ~(CharAvail)
        end
        chr = GetChar;
    end
catch
    disp(lastCommandScreen);
end

command = ' ';

if (logFid ~= -1)     % flush the logfile
    fclose(logFid);
    [logFid, txt] = fopen(logFilename,'at');
end
