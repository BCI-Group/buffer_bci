%
% THIS IS JUST FOR TESTING UNTIL WE HAVE THE FINAL CLASSIFIER AND HOW IT
% WORKS --> Alejandro
%
% THE ONLY CODE I HAVE MODIFIED IS AROUND LINE 170 AND HERE IN THE
% BEGINNING (and minor changes to make this work.)
% COPIED FROM imContFeedbackStimulus
%
udpr = dsp.UDPReceiver('LocalIPPort',6666,'MessageDataType','int8');
% To prevent the loss of packets, call the |setup| method
% on the object before the first call to the |step| method.
% Here I just do the first step.
step(udpr);

configureExp;
if ( ~exist('contFeedbackTrialDuration') || isempty(contFeedbackTrialDuration) )
  contFeedbackTrialDuration=trialDuration;
end;

cybathalon = struct('host','127.0.0.1','port',5555,'player',1,...
                    'cmdlabels',{{'jump' 'slide' 'speed' 'rest'}},'cmddict',[2 3 1 99],...
						  'cmdColors',[.6 0 .6;.6 .6 0;0 .5 0;.3 .3 .3]',...
                    'socket',[],'socketaddress',[]);
% open socket to the cybathalon game
[cybathalon.socket]=javaObject('java.net.DatagramSocket'); % create a UDP socket
cybathalon.socketaddress=javaObject('java.net.InetSocketAddress',cybathalon.host,cybathalon.port);
cybathalon.socket.connect(cybathalon.socketaddress); % connect to host/port
connectionWarned=0;
%hudps = dsp.UDPSender('RemoteIPAddress','192.168.1.111','RemoteIPPort',5555);


% make the target sequence
tgtSeq=mkStimSeqRand(nSymbs,nSeq);

% make the stimulus display
fig=figure(2);
clf;
set(fig,'Name','Imagined Movement','color',winColor,'menubar','none','toolbar','none','doublebuffer','on');
ax=axes('position',[0.025 0.025 .95 .95],'units','normalized','visible','off','box','off',...
        'xtick',[],'xticklabelmode','manual','ytick',[],'yticklabelmode','manual',...
        'color',winColor,'DrawMode','fast','nextplot','replacechildren',...
        'xlim',[-1.5 1.5],'ylim',[-1.5 1.5],'Ydir','normal');

stimPos=[]; h=[];
stimRadius=diff(axLim)/4;
cursorSize=stimRadius/2;
theta=linspace(0,2*pi,nSymbs+1);
if ( mod(nSymbs,2)==1 ) theta=theta+pi/2; end; % ensure left-right symetric by making odd 0=up
theta=theta(1:end-1);
stimPos=[cos(theta);sin(theta)];

%Create a text object with no text in it, center it, set font and color
set(fig,'Units','pixel');wSize=get(fig,'position');set(fig,'units','normalized');% win size in pixels
txthdl = text(mean(get(ax,'xlim')),mean(get(ax,'ylim')),' ',...
				  'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle',...
				  'fontunits','pixel','fontsize',.05*wSize(4),...
				  'color',[0.75 0.75 0.75],'visible','off');

set(txthdl,'string', 'Click mouse when ready', 'visible', 'on'); drawnow;              
              
for hi=1:nSymbs; 
  % set tgt to the color of that part of the game
  h(hi)=rectangle('curvature',[1 1],'position',[stimPos(:,hi)-stimRadius/2;stimRadius*[1;1]],...
                  'facecolor',cybathalon.cmdColors(:,hi));

  if ( ~isempty(symbCue) ) % cue-text
	 htxt(hi)=text(stimPos(1,hi),stimPos(2,hi),{symbCue{hi} '->' cybathalon.cmdlabels{hi}},...
						'HorizontalAlignment','center',...
						'fontunits','pixel','fontsize',.05*wSize(4),...
						'color',txtColor,'visible','on');
  end  
end;
% add symbol for the center of the screen
stimPos(:,nSymbs+1)=[0 0];
h(nSymbs+1)=rectangle('curvature',[1 1],'position',[stimPos(:,end)-stimRadius/4;stimRadius/2*[1;1]],...
                      'facecolor',bgColor); 
set(gca,'visible','off');

waitforbuttonpress;
set(txthdl,'visible', 'off'); drawnow;

% play the stimulus
sendEvent('stimulus.testing','start');
% initialize the state so don't miss classifier prediction events
state=[]; 
endTesting=false; dvs=[];
prevStage=[];
endCont = 0;
for si=1:max(100000,nSeq);

  if ( ~ishandle(fig) || endTesting ) break; end;
  
  sleepSec(intertrialDuration);
  % show the screen to alert the subject to trial start
  set(h(end),'facecolor',fixColor); % red fixation indicates trial about to start/baseline
  drawnow;% expose; % N.B. needs a full drawnow for some reason
  sendEvent('stimulus.baseline','start');
  sleepSec(baselineDuration);
  sendEvent('stimulus.baseline','end');
  sendEvent('stimulus.trial','start');
  
%   %------------------------------- trial interval --------------
%   % for the trial duration update the fixatation point in response to prediction events
%   % initial fixation point position
%   fixPos = stimPos(:,end);
%   state  = buffer('poll'); % Ensure we ignore any predictions before the trial start  
%   preds  = []; % buffer of all predictions since trial start
%   dv     = zeros(nSymbs,1); % current classifier decision value
%   prob   = ones(nSymbs,1)./nSymbs; % start with equal prob over everything
%   trlStartTime=getwTime();
%   timetogo = contFeedbackTrialDuration;
%   while (timetogo>0) % loop until the trail end
% 	 curTime  = getwTime();
%     timetogo = contFeedbackTrialDuration - (curTime-trlStartTime); % time left to run in this trial
%     % wait for new prediction events to process *or* end of trial time
%     [events,state,nsamples,nevents] = buffer_newevents(buffhost,buffport,state,'classifier.prediction',[],timetogo*1000);
%     if ( isempty(events) ) 
% 		if ( timetogo>.2 ) 
%          fprintf('%d) no predictions!\n',nsamples); 
%       end;
%     else
%       for ei=1:numel(events);
%         ev=events(ei);% event to process        
%         dv=ev.value;  % get the classifier prediction
%         preds=[preds dv]; % accumulate all predictions since trial start
%         
%         if ( verb>=0 ) 
%            prob=exp((dv-max(dv))); prob=prob./sum(prob); % robust soft-max prob computation
%            fprintf('%d) dv:[%s]\tPr:[%s]\n',ev.sample,sprintf('%5.4f ',dv),sprintf('%5.4f ',prob));
%         end;
%       end
% 
% 	 end % if prediction events to process
% 
%     % convert from dv to normalised probability
%     dv  =mean(preds,2); % feedback is average prediction since trial start
%     prob=exp((dv-max(dv))); prob=prob./sum(prob); % robust soft-max prob computation
% 
%     % feedback information... simply move in direction detected by the BCI
%     if(numel(prob)>size(stimPos,2)) prob=[prob(1:size(stimPos,2)-1);sum(prob(size(stimPos,2):end))];end
% 	dx      = stimPos(:,1:numel(prob))*prob(:); % change in position is weighted by class probs
%     fixPos  = dx; % new fix pos is weighted by classifier output
%     %move the fixation to reflect feedback
%     cursorPos=get(h(end),'position'); cursorPos=cursorPos(:);
% 	set(h(end),'position',[fixPos-.5*cursorPos(3:4);cursorPos(3:4)]);
%     drawnow; % update the display after all events processed    
%   end % while time to go

						  %------------------------------- feedback --------------
	predTgt=[];
    % Get current stage of the game
    actStage=step(udpr);
    if isempty(actStage)
        actStage = prevStage;
        endCont = endCont + 1;
    else
        endCont = 0;
    end
    prevStage = actStage;
    
    if endCont>=5;
        endTesting = true;
    end
    
    % TODO - DELETE THIS - JUST FOR TESTING PORPUSES.
    randomPreds = [0 1 2 3 2 1 2 3 1 2 3 2 1 2 2 2 1 3 2 1 2 3 2 0 0 0 1 2 ...
        0 1 2 3 2 1 2 3 1 2 3 2 1 2 2 2 1 3 2 1 2 3 2 0 0 0 1 2 ...
        0 1 2 3 2 1 2 3 1 2 3 2 1 2 2 2 1 3 2 1 2 3 2 0 0 0 1 2];
    preds = randomPreds(si);
    
   if ( isempty(preds) ) 
     fprintf(1,'Error! no predictions after %gs, continuing (%d samp, %d evt)\n',curTime-trlStartTime,state.nSamples,state.nEvents);
     set(h(end),'facecolor',fbColor); % fix turns blue to show now pred recieved
     drawnow;
   % TODO should sent a signal to the ErrP signal processor here too?
   else
     % average of the predictions is used for the final decision
     dv = mean(preds,2);
     prob=exp((dv-max(dv))); prob=prob./sum(prob); % robust soft-max prob computation
    
     %[ans,predTgt]=max(dv); % prediction is max classifier output
     predTgt = preds;
     if predTgt~=0
     set(h(predTgt),'facecolor',fbColor);
     end
     drawnow;
     
     % send the command to the game server
	 try;
        % tmp = 10*cybathalon.player+cybathalon.cmddict(predTgt)
		cybathalon.socket.send(javaObject('java.net.DatagramPacket',uint8([10*cybathalon.player+cybathalon.cmddict(predTgt) 0]),1));
        %step(hudps, uint8(11));
        sendEvent('stimulus_errp.target',predTgt==actStage);
     catch;
		if ( connectionWarned<10 )
		  connectionWarned=connectionWarned+1;
		  warning('Error sending to the Cybathalon game.  Is it running?\n');
		end
	 end

  end % if classifier prediction
  sleepSec(feedbackDuration);
  
  % reset the cue and fixation point to indicate trial has finished  
  if ( ~isempty(predTgt) ) 
      if predTgt~=0
	set(h(predTgt),'facecolor',cybathalon.cmdColors(:,predTgt)); % reset the feedback
      end
  end
  set(h(end),'facecolor',bgColor);
  if ( ~isempty(symbCue) ) set(txthdl,'visible','off'); end
  % also reset the position of the fixation point
  drawnow;
  sendEvent('stimulus.trial','end');
  
end % loop over sequences in the experiment
% end training marker
sendEvent('stimulus.testing','end');
