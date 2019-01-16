

% set-up commands
protocolLength = size(protocol,1); % used many times

% array of actions, {1,1} = number of elements
% {:,1} p - parallel, s - serial  {:,2} - port  {:,3} - command
data_cmd = repmat({0, '', ''},20,1); % pre-allocate space

flip = 0;       % flip square/signal HAS TO start with 0

Screen('CopyWindow',scrBg,scrOffline);
Screen('CopyWindow',scrBg,scrLast);
pretime = GetSecs();
if triggeredStart(1) && triggeredStart(2) % active trigger
    if parallel_codes(6)
        parallel_states(parallel_codes(6)) = 1; % trigger
        parallel_out(parallel_codes(1),bin2dec(num2str(parallel_states)));
    end

   if verbose
        Screen(w,'DrawText',' Wait for trigger! ', 25, 30, infocolor);
   end
   parallel_out(hex2dec('EC02'),uint32(bitset(uint8(parallel_in(hex2dec('EC02'))),6))); % set to read
   p = parallel_in(triggeredStart(1));
   %disp(num2str([bitand(2^triggeredStart(3),p) p uint8(triggeredStart(2)) triggeredStart(3)  ]));
   while ~bitand(2^(triggeredStart(3)-1),p) && (triggeredStart(4)/1000 > GetSecs() - pretime)
       p = uint8(parallel_in(triggeredStart(1)));
   end
   parallel_out(hex2dec('EC02'),uint32(bitset(uint8(parallel_in(hex2dec('EC02'))),6,0))); % set to write
   if parallel_codes(6)
        parallel_states(parallel_codes(6)) = 0; % trigger received
   end

   if ~bitand(2^(triggeredStart(3)-1),p) % not triggered but time-out
        triggeringError = true;
   end
else
   for waitsync=1:waitFrames(3)   % give some time to the sender
       Screen(w,'WaitBlanking');
   end
   if parallel_codes(4) % first/last
       parallel_states(parallel_codes(4)) = 1;
   end
end

if ~triggeringError
  pretime = GetSecs();

  % present - procItem=1 for init first
  procItem = 1; waitItem = 1;
  while procItem < protocolLength+2 % wait for poststim time
    infopos = 15;
    data_cmd{1,1} = 1; % valid actions in this array (1 = no action)
    doit = (procItem <= protocolLength); % if last line don't comp just wait
    Screen('CopyWindow',scrLast,scrOffline);
    while doit % do until duration not zero
        % generate next frame
        if verbose > 2 % debug
            infocolor = txtcolor;
        else
            if bgcolor < 160
                infocolor = bgcolor+40;
            else
                infocolor = bgcolor-70;
            end
        end
        if protocol(procItem,1) > 0 % bmp
             if protocol(procItem,3) ~= 0 || protocol(procItem,4) ~= 0
                 srcRect = [max(screenRect(1)+protocol(procItem,3),0)                       max(screenRect(2)+protocol(procItem,4),0)                        min(screenRect(3)+protocol(procItem,3),screenRect(3))                        min(screenRect(4)+protocol(procItem,4),screenRect(4))];
                 destRect = [max(screenRect(1)-protocol(procItem,3),0)                        max(screenRect(2)-protocol(procItem,4),0)                        min(screenRect(3)-protocol(procItem,3),screenRect(3))                       min(screenRect(4)-protocol(procItem,4),screenRect(4))];
                 Screen('CopyWindow',scrBg,scrOffline);
             else
                 srcRect = screenRect;
                 destRect = screenRect;
             end
            Screen('CopyWindow',scrOff(protocol(procItem,1)),scrOffline,srcRect,destRect);
        elseif protocol(procItem,1) == 0 % bg -1
            switch protocol(procItem,3)
            case 0 % bg color
                Screen('CopyWindow',scrBg,scrOffline);
            case 1 % wait
            case 2 % full-field
                Screen(scrOffline,'FillRect',uint8(protocol(procItem,4)));
                if isempty(polyMask) && verbose < 3
                    if protocol(procItem,4) < 160
                        infocolor = protocol(procItem,4)+40;
                    else
                        infocolor = protocol(procItem,4)-70;
                    end
                end
            case 3

            case 4 % user
                cmd = user_commands{protocol(procItem,4)};

                data_cmd{1,1} = data_cmd{1,1} + 1;
                data_cmd{data_cmd{1,1},1} = cmd{5};
                data_cmd{data_cmd{1,1},2} = cmd{6};
                data_cmd{data_cmd{1,1},3} = cmd{7};

                %% time 0.04 / 24
                if cmd{5} == 'p'
                    if cmd{6} == parallel_codes(1) && abs(cmd{3}) < 9
                       data_cmd{1,1} = data_cmd{1,1} - 1; % dont store
                       % same parallel port, so cmd{3} is a pin:
                       if cmd{3} < 0 % -1 0 4 -2 = pin2 is low
                           parallel_codes(9+cmd{3}) = 0;
                       else          % -1 0 4 2  = pin2 is high
                           parallel_codes(9-cmd{3}) = 1;
                       end
                    end
                elseif cmd{5} == 's' || cmd{5} == 'u'
                    so = so_arr{str2double(cmd{2}(4))};
                    data_cmd{data_cmd{1,1},2} = so;
                    if ~isempty(so) && so.status(1) == 'o'
                       if so.BytesAvailable
                            fread(so, so.BytesAvailable);
                       end
                    end
                end
            case 5 % till polychrome
                data_cmd{1,1} = data_cmd{1,1} + 1;
                data_cmd{data_cmd{1,1},1} = 't';
                data_cmd{data_cmd{1,1},2} = protocol(procItem,4); % color
            end
        end
        if ~isempty(polyMask)
             Screen(scrOffline,'FillPoly',bgcolor,polyMask);
        end

        if verbose == 3 % debug
             Screen(scrOffline,'FillRect',255*flip,[0 0 25 25])
             flip = ~flip;
        end
        Screen('CopyWindow',scrOffline,scrLast);

        if verbose > 1 && protocol(procItem,2)
          if protocol(procItem,3) == 4
             Screen(scrOffline,'DrawText', [cmd{4} ' (' cmd{2} ' ' cmd{3} ')'], 25, infopos, infocolor);infopos=infopos+15;
          end
          if protocol(procItem,3) == 5
             Screen(scrOffline,'DrawText', [' Till Polychrome to ' num2str(protocol(procItem,4)) 'nm'], 25, infopos, infocolor);infopos=infopos+15;
          end
        end

        if protocol(procItem,2) || procItem == protocolLength
             doit = false;
             if verbose > 1 % write only the last
                 %% time 0.02 / 36
                 txt = [protocolFileName ' step ' num2str(procItem-1) 'of' num2str(protocolLength) ' remains ' num2str(sum(protocol(procItem:end,2))*frametime) 's'];
                 Screen(scrOffline,'DrawText',txt, 25, screenRect(4), infocolor);
             end
        else % if duration == 0 do the next line
            procItem = procItem + 1;
        end
    end % doit while duration not zero

    if parallel_codes(5) % show action after next Blanking when its on screen
       parallel_states(parallel_codes(5)) = waitItem < protocolLength; % posttime not signaled
       parallel_out(parallel_codes(1),2*(2*(2*(2*(2*(2*(2*parallel_states(1)+parallel_states(2))+parallel_states(3))+parallel_states(4))+parallel_states(5))+parallel_states(6))+parallel_states(7))+parallel_states(8));
    end

    timingTest(procItem,2) = GetSecs() - pretime;

    % wait the req. time
    for wait_i=1:protocol(waitItem,2)-1
        Screen(w,'WaitBlanking');
        % check keyboard activity
       [keyIsDown]= Screen3('GetMouseHelper', -1); 
       if keyIsDown
           break;
       end
    end

    if parallel_codes(3) %first frame on screen
       parallel_states(parallel_codes(3)) = (procItem <= protocolLength && protocol(procItem,2)); % stim
    end
    if parallel_codes(5) % show action after next Blanking when its on screen
       parallel_states(parallel_codes(5)) = (procItem == 1); % pretime not signaled
    end
    % Copy to monitor
    Screen('CopyWindow',scrOffline,w);
    % this is the last wait frame of the previous screen
    if protocol(waitItem,2) || waitItem == 1 % if zero dont wait
        Screen(w,'WaitBlanking');
    end
    if parallel_codes(1) % show action after next Blanking when its on screen
       parallel_out(parallel_codes(1),2*(2*(2*(2*(2*(2*(2*parallel_states(1)+parallel_states(2))+parallel_states(3))+parallel_states(4))+parallel_states(5))+parallel_states(6))+parallel_states(7))+parallel_states(8));
    end
    if parallel_codes(4)
       parallel_states(parallel_codes(4)) = 0;
    end

    posttime = GetSecs();
    timingTest(waitItem,1) = posttime - pretime;
    pretime = posttime;
    waitItem = procItem;

    % Do the data communications
    for dataItem=2:data_cmd{1,1} % first line is the number of actions
        switch data_cmd{dataItem,1}
            case 'p'
               parallel_out(data_cmd{dataItem,2}, data_cmd{dataItem,3});
            case 's'
               while ~strcmp('idle',data_cmd{dataItem,2}.TransferStatus)
               end
               fprintf(data_cmd{dataItem,2}, data_cmd{dataItem,3},'async');
            case 'u'
               buffer(3) = data_cmd{dataItem,2}.UserData(3);
               value = round(data_cmd{dataItem,3}*data_cmd{dataItem,2}.UserData(1));
               buffer(5)= floor(value/256);
               buffer(6)= mod(value,256);
               checksum = 256*256-1-sum(buffer(1:22));
               buffer(23)= floor(checksum/256);
               buffer(24)= mod(checksum,256);
               fwrite(data_cmd{dataItem,2},buffer);

            case 't'
               calllib('TILLPolychrome','TILLPolychrome_SetRestingWavelength',polychrome.pTill,data_cmd{dataItem,2});
        end
    end
    procItem = procItem + 1;
    % check keyboard activity
   if ~keyIsDown                              
       [keyIsDown]= Screen3('GetMouseHelper', -1);
   end
   if keyIsDown
       break;
   end
  end
end % no trigger error

% set all signals to zero
if parallel_codes(4)
    parallel_states(parallel_codes(4)) = 1;
    parallel_out(parallel_codes(1),bin2dec(num2str(parallel_states)));
    Screen(w,'WaitBlanking');
end
parallel_states = logical(zeros(1,8));
if parallel_codes(1)
    parallel_out(parallel_codes(1),bin2dec(num2str(parallel_states)));
end

timingTest = timingTest(1:end-1,:); % last line is after postrec
