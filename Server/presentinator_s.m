% case 'S' % stimulus: [action frames posX um posY um]

command = strrep(command,'\n',sprintf('\n'));
Screen('CopyWindow',scrBg,w); % clear screen
bullseyeOn = 0;
if isempty(command(3:end))           % use last command
    command = last_s_command;
end
last_s_command = command;

if isempty(command(3:end))
   command = ' '; % delete command buffer
   continue;
end

rgb = regexp(command(2:end),'[ \f\r\t\v]*([^\n])*[\n]*(.*)','tokens');
command = rgb{1}{2};
protocolFileName = rgb{1}{1};
bmppathstr = fileparts(protocolFileName);

if isempty(command)
    command = ' '; % delete command buffer
    protocol = [];
    % load protocol: protocolFileName
    if (verbose > 1)
        Screen(w,'DrawText',['Load ' protocolFileName], 25, 15, infocolor);
    end
    protocol = [];

    fid = fopen(protocolFileName,'r');
    if fid == -1
        txt = ['Missing file ' protocolFileName];
        presentinator_error;
        continue;  
    end
    params = fgetl(fid); % first line
    params = regexp(params,' (\S+)\%(\d+)\%\S+','tokens');
    tline = fgetl(fid); % bmpdir/comment line
    tline = strtok(tline,sprintf('\t'));
    if exist(tline,'dir')
        bmppathstr = tline; % bmpdir
    end

    while true
        tline = fgetl(fid);
        if ~ischar(tline),   break,   end % until EOF
        % replace params
        for pid=1:length(params)
           tline = strrep(tline,params{pid}{1},params{pid}{2});
        end
        clear T;
        tline = regexp(tline,'(\S+)\s+(\S+)\s+(\S*)\s*(\S*)','tokens');
        try
            protocol(end+1,:) = cellfun(@eval, tline{1});
        catch % hopefully only T is missing
            try
                totaltime = eval(tline{1}{2});
                for T = 0:1/frameRateFactor:totaltime-1/frameRateFactor
                    try
                        protocol(end+1,:) = cellfun(@eval, tline{1});
                        protocol(end,2) = 1/frameRateFactor;
                    catch 
                        protocol(end+1,:) = [-1 1/frameRateFactor -3 0];
                        txt = ['Unknown parameter? in stim file'];
                        presentinator_error;
                    end
                end
            catch
                protocol(end+1,:) = [-1 0 -3 0];
                txt = ['Unknown duration: ' tline{1}{2}];
                presentinator_error;
            end
        end
    end
    fclose(fid);
else
    if (verbose > 1)
        Screen(w,'DrawText',['Skip ' protocolFileName], 25, 15, infocolor);
    end
%     fprintf(logFid, '>%s', command);
    protocol = textscan(command,'%f%f%f%f', -1, 'delimiter', sprintf(' \t'), 'multipleDelimsAsOne', 1); % 'headerlines',1
    command = ' '; % delete command buffer
    if isempty(protocol)
        txt = ['Missing command: ' rgb{1}{2}];
        presentinator_error;
        continue;  
    end
    protocol = [protocol{:}];
end

if size(protocol,2) == 2 % old style file
    protocol(:,3) = 0;
    protocol(:,4) = 0;
end
if size(protocol,2) == 5 % new style file
    ;
end
% empty line can make NaN
protocol = protocol(~isnan(protocol(:,1)),:);
protocol = protocol(isfinite(protocol(:,2)),:);

% first line for init
protocol = [-1 waitFrames(1) 0 0; protocol]; % wait 1 blink at first
if length(waitFrames) > 1
    protocol = [protocol; -1 waitFrames(2) 0 0];
end
% bmp id 1 based
protocol(:,1) = floor(protocol(:,1) + 1);

% duration in blankings 
protocol(:,2) = ceil(protocol(:,2)*frameRateFactor);

% offset in pixel
bmplines = find(protocol(:,1) > 0);
protocol(bmplines,3) = protocol(bmplines,3)/um2pixel;
protocol(bmplines,4) = protocol(bmplines,4)/um2pixel;
% external offset
protocol(bmplines,3) = floor(-protocol(bmplines,3)-offset(1));
protocol(bmplines,4) = floor(-protocol(bmplines,4)+offset(2));

% check user command exist
so = instrfind();
for i=1:size(so,2)
    so_arr{str2num(so(i).Port(4))} = so(i);
    %TODO? cmd{6} = so_arr{str2double(cmd{2}(4))};

end
bmplines = find(protocol(:,1) == 0 & protocol(:,3) == 4);      
for i=1:length(bmplines)
    if protocol(bmplines(i),4) < 1 || ...
            protocol(bmplines(i),4) > length(user_commands)  || ...
            isempty(user_commands{protocol(bmplines(i),4)})
        txt = ['Unknown user command ' num2str(protocol(bmplines(i),4)) ' in stimulus'];
        presentinator_error; 
        protocol(bmplines(i),3) = -3;
    end
end
bmplines = find(protocol(:,1) == 0 & protocol(:,3) == 5);      
if ~isempty(bmplines) % Polychrome is in use
    if ~polychrome.exist
        txt = ['TILL Polychrome dll is missing'];
        presentinator_error; 
        protocol(bmplines,3) = -3;
    else % open and set to bgcolor
        try
            if ~polychrome.open 
                [errCode polychrome.pTill] = calllib('TILLPolychrome','TILLPolychrome_Open',polychrome.pTill,0);
            else
                errCode = 0;    
            end
            if ~errCode
                polychrome.open = true;
                errCode = calllib('TILLPolychrome','TILLPolychrome_SetRestingWavelength',polychrome.pTill,polychrome.color);
            end
        catch
            txt = 'TILL Polychrome crashed';
            presentinator_error; 
            protocol(bmplines,3) = -3;
        end
        if errCode
            txt = ['TILL Polychrome errorcode: ' num2str(errCode)];
            presentinator_error; 
            protocol(bmplines,3) = -3;
        end
    end
end

% convert color
bmplines = find(protocol(:,1) == 0 & protocol(:,3) == 2); 
for i=1:length(bmplines)
    protocol(bmplines(i),4) = clut(max(min(round(protocol(bmplines(i),4))+1,length(clut)),1));
end

% load imgs
if (verbose > 1)
    Screen(w,'DrawText',' Load bitmaps', 500, 15, infocolor);
end

% if new directory
if ~strcmp(pathstr_old,bmppathstr) || isempty(scrOff)
    % sort filenames
    bmpfiles = dir(fullfile(bmppathstr , '*.bmp'));
    bmpfiles = sort({bmpfiles.name});
    pngfiles = dir(fullfile(bmppathstr , '*.png'));
    pngfiles = sort({pngfiles.name});
    bmpfiles = [bmpfiles pngfiles];

    % clear old bitmaps
    pathstr_old = bmppathstr;
    scrOff = zeros(1,size(bmpfiles,2));
end
                                                  % 2:end    
usedbmps = unique(protocol(find(protocol(2:end,1) > 0)+1,1))';
for i=usedbmps
    if i < length(scrOff) && scrOff(i)    % already loaded
        continue;
    end
    if i > length(bmpfiles)
        txt = ['Missing bmp id ' num2str(i-1) ' in ' bmppathstr];
        presentinator_error;
        protocol((protocol(:,1) == i),1) = 0;
        protocol((protocol(:,1) == i),3) = -3;
        continue;
    end

    [imageArray map] = imread(fullfile(bmppathstr,bmpfiles{i}));
    imageInfo = imfinfo(fullfile(bmppathstr,bmpfiles{i}));

    if size(map,1) > 0
       if (isfield(imageInfo,'SimpleTransparencyData'))    
          tp = logical(1-imageInfo.SimpleTransparencyData);
          map(tp,:) = repmat(bgcolor/255, size(map(tp,1)), 3); 
       end
       imageArray = ind2gray(imageArray, map); % resolve indexed file
    end
    if Zoomimage(2) ~= 0
        imageArray = double(imageArray);

        imageArray = imrotate(imageArray+3, -1*abs(Zoomimage(2))); % rotate (3 is arbitrary shift)
        imageArray = (imageArray==0)*(bgcolor+3) + imageArray - 3;    % correct bgcolor
        if Zoomimage(2) < 0 % flip
            imageArray = fliplr(imageArray);
        end

        imageArray = uint8(imageArray);
    end
    % TODO modify colors based on clut!


    scrOff(i)  = Screen(w, 'OpenOffscreenWindow', 0, screenRect);
    Screen(scrOff(i),'FillRect',bgcolor,screenRect);    
    destRect = 0.5*[screenRect(3)-Zoomimage(1)*size(imageArray,2) screenRect(4)-Zoomimage(1)*size(imageArray,1) screenRect(3)+Zoomimage(1)*size(imageArray,2) screenRect(4)+Zoomimage(1)*size(imageArray,1)];
    destRect = [max(destRect(1),0) max(destRect(2),0) min(destRect(3),screenRect(3)) min(destRect(4),screenRect(4))];

    Screen(scrOff(i),'PutImage',imageArray,destRect);
end

if port % if port == 0 it was keyboard event
     txt = mat2str(protocol);
     pnet(udp,'write', sprintf(['STIM @ %s %s\n' strrep(txt(2:min(length(txt)-1,40000)),';','\n')], ...
         datestr(now), protocolFileName));     
     pnet(udp,'writepacket',ip,port);   % Send buffer as UDP packet
end

% for UTA commands
buffer(1:24) = uint8(0);
buffer(1)= hex2dec('AA');
buffer(2)= hex2dec('55');
buffer(4)= hex2dec('1F'); % setvoltage

% start 
triggeringError = false; % if false trigger error
timingTest = zeros(size(protocol,1),2);
keyIsDown = false; % to break free

%Rush(rushloop,2);
presentinator_rush; 

Screen('CopyWindow',scrBg,w); % clear screen

if triggeringError
    txt = ['No trigger arrived within ' num2str(triggeredStart(4)) 'ms'];
    presentinator_error;
elseif ~keyIsDown
    timingTest = timingTest / frametime;
    stepnum = size(timingTest,1);
    timingTest(:,1) = timingTest(:,1) - protocol(1:stepnum,2);
    errorlines = find(abs(timingTest(2:end,1))>= 1.1 ,3,'first');
    errorlines = [errorlines+1; find(abs(timingTest(:,2)) > 1.1 ,3,'first')];
    errorlines = sort(unique(errorlines));
    if ~isempty(errorlines)
        txt = ['Timing error! ' ...
            num2str(reshape(timingTest(errorlines,:)',1, length(errorlines)*2)) 'frames'];
        presentinator_error;
    end
    longestProcessing = ceil(100*max(timingTest(:,2)));
end

% if ~strcmp(lastCommandScreen(1:5),'ERROR')
%     lastCommandScreen = [];
% end

if keyIsDown % user break;
    txt = 'User interruption';
    presentinator_log;
     
    % stop the whole sequence
    if ~isempty(protocolCommands)
        if port % if port == 0 it was keyboard event
             pnet(udp,'write', ['BREAK @ %s ' datestr(now)]);     
             pnet(udp,'writepacket',ip,port);   % Send buffer as UDP packet
        end
    end
    protocolCommands = ''; 
end    

protocol = [];
command = ' '; % delete command buffer

