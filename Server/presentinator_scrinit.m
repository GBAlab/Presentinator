pathstr_old = [];
scrOff = [];
      
% init screen 
[w, screenRect] = Screen(0,'OpenWindow',[],[],32); % get screen size
Screen(w,'DrawText','Initialisation ', 25, 25, txtcolor);
scrOffline = Screen(w, 'OpenOffscreenWindow',bgcolor, screenRect);
scrBg = Screen(w, 'OpenOffscreenWindow',bgcolor, screenRect);
scrLast = Screen(w, 'OpenOffscreenWindow',bgcolor, screenRect);
srcRect = zeros(1,4);
destRect = zeros(1,4);

% load bullseye
imageArray = imread('bullseye.bmp');
scrBullseye  = Screen(w, 'OpenOffscreenWindow',0, screenRect);
Screen(scrBullseye,'PutImage',imageArray,screenRect);
HideCursor();

Screen(w,'DrawText','Measuring the FrameRate...', 100,100);
%theory:   frametime = 1/Screen(w,'FrameRate');
%practice:
Screen(w,'WaitBlanking');
pretime = GetSecs();
for timing=1:500
    Screen(w,'WaitBlanking');
end
frametime = (GetSecs()-pretime)/500;
