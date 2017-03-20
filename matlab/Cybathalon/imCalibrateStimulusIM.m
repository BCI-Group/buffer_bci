%----------------------------------------------------------------------
% Graphical interface used during the imaginary movement calibration.
%
% The interface components are three main circles and a smaller one in the
% middle. A small progress indicator is also present on the left corner of
% the window.
%
% The experiment is as follows: All the circles will be shown in grey.
% After some predefined time, the circle in the middle will turn red
% indicating that a command is about to take place. Then, a random order
% will be indicated by highlighting one of the three main circles and
% writing the name of the body part to move on the center of the screen.
% This circle is repeated until the end of the experiment.
%
%
% All changes on the interface are are followed by an event, so we can
% communicate this script with the other parts of the program.
%
% Author: Alejandro Gonz�lez Rogel (s4805550)
%         Marzieh Borhanazad (s4542096)
%         Ankur Ankan (s4753828)
% Forked from https://github.com/jadref/buffer_bci
%----------------------------------------------------------------------


configureExp;

% Make a rangom target sequence for calibration
tgtSeq=mkStimSeqRand(nSymbs,nSeq);

% Create the interface
fig=figure(2);
set(fig,'Name','Imagined Movement','color',winColor,'menubar','none','toolbar','none','doublebuffer','on');
clf;
ax=axes('position',[0.025 0.025 .95 .95],'units','normalized','visible','off','box','off',...
    'xtick',[],'xticklabelmode','manual','ytick',[],'yticklabelmode','manual',...
    'color',winColor,'DrawMode','fast','nextplot','replacechildren',...
    'xlim',axLim,'ylim',axLim,'Ydir','normal');

stimPos=[]; h=[]; htxt=[];
stimRadius=diff(axLim)/4;
cursorSize=stimRadius/2;
theta=linspace(0,2*pi,nSymbs+1);
if ( mod(nSymbs,2)==1 ) theta=theta+pi/2; end; % ensure left-right symetric by making odd 0=up
theta=theta(1:end-1);
stimPos=[cos(theta);sin(theta)];
for hi=1:nSymbs;
    h(hi)=rectangle('curvature',[1 1],'position',[stimPos(:,hi)-stimRadius/2;stimRadius*[1;1]],...
        'facecolor',bgColor);
end;
% add symbol for the center of the screen
stimPos(:,nSymbs+1)=[0 0];
h(nSymbs+1)=rectangle('curvature',[1 1],'position',[stimPos(:,nSymbs+1)-cursorSize/2;cursorSize*[1;1]],...
    'facecolor',bgColor);
set(gca,'visible','off');

%Create a text object with no text in it, center it, set font and color
set(fig,'Units','pixel');wSize=get(fig,'position');set(fig,'units','normalized');% win size in pixels
txthdl = text(mean(get(ax,'xlim')),mean(get(ax,'ylim')),' ',...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle',...
    'fontunits','pixel','fontsize',.05*wSize(4),...
    'color',txtColor,'visible','off');

% Progress indicator
progressText=text(axLim(1),axLim(2),sprintf('%2d/%2d',0,nSeq),...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'top',...
    'fontunits','pixel','fontsize',.05*wSize(4),...
    'color',txtColor,'visible','on');


% Prepare for start
% reset the cue and fixation point to indicate trial has finished
set(h(:),'facecolor',bgColor);
sendEvent('stimulus_im.calibration','start');

set(txthdl,'string', {'Imagine moving the bodypart written in screen.'...
    'Click mouse when ready'}, 'visible', 'on', 'color', txtColor); drawnow;
waitforbuttonpress;
set(txthdl,'visible', 'off'); drawnow;

% Main loop
for si=1:nSeq;
    %Update progress indicator
    set(progressText,'string',sprintf('%2d/%2d',si,nSeq));
    drawnow;
    
    % If enough iterations have been done, rest
    if (mod(si,15)==0)
        set(txthdl,'string',{'Take as much time as you need to rest.'...
            'Then, press any key to continue.'}, 'visible', 'on', 'color',[1 1 1]);
        drawnow;
        waitforbuttonpress;
        set(txthdl,'string',{''}, 'visible', 'on', 'color',[1 1 1]);
        drawnow;
    end
    
    if ( ~ishandle(fig) ) break; end;
    
    % Break between trials
    sleepSec(intertrialDuration);
    % show the screen to alert the subject to trial start
    set(h(end),'facecolor',fixColor); % red fixation indicates trial about to start/baseline
    drawnow;% expose; % N.B. needs a full drawnow for some reason
    sendEvent('stimulus_im.baseline','start');
    if ( ~isempty(baselineClass) ) % treat baseline as a special class
        sendEvent('stimulus_im.target',baselineClass);
    end
    sleepSec(baselineDuration);
    sendEvent('stimulus_im.baseline','end');
    
    % show the target
    tgtIdx=find(tgtSeq(:,si)>0);
    set(h(tgtSeq(:,si)>0),'facecolor',tgtColor);
    set(h(tgtSeq(:,si)<=0),'facecolor',bgColor);
    if ( ~isempty(symbCue) )
        set(txthdl,'string',sprintf('%s ',symbCue{tgtIdx}),'color',txtColor,'visible','on');
        tgtNm = '';
        for ti=1:numel(tgtIdx);
            if(ti>1) tgtNm=[tgtNm ' + ']; end;
            tgtNm=sprintf('%s%d %s ',tgtNm,tgtIdx,symbCue{tgtIdx});
        end
    else
        tgtNm = tgtIdx; % human-name is position number
    end
    set(h(end),'facecolor',fixColor); % green fixation indicates trial running
    fprintf('%d) tgt=%10s : ',si,tgtNm);
    sendEvent('stimulus_im.trial','start');
    for ei=1:ceil(trialDuration./epochDuration);
        sendEvent('stimulus_im.target',tgtNm); % Event for SigProc to start recording
        drawnow;% expose; % N.B. needs a full drawnow for some reason
        % wait for trial end
        sleepSec(epochDuration);
    end
    
    % Reset the cue and fixation point to indicate trial has finished
    set(h(:),'facecolor',bgColor);
    if ( ~isempty(symbCue) ) set(txthdl,'visible','off'); end
    drawnow;
    sendEvent('stimulus_im.trial','end');
    
    ftime=getwTime();
    fprintf('\n');
end % End of the main loop
% end training marker
sendEvent('stimulus_im.calibration','end');

if ( ishandle(fig) ) % thanks message
    set(txthdl,'string',{'That ends the training phase.',...
        'Thanks for your patience'}, 'visible', 'on', 'color', txtColor);
    pause(3);
    close(fig);
end


