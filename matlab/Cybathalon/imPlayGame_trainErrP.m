%----------------------------------------------------------------------
% Allows the user to play the game while collecting data about the ErrP signal
% after every instruction that is sended to the game.
%
% Two different connections are needed when connecting to the game. One
% will be used to send instructions to the game, the other one will be used
% to receive feedback about the stage the user is in (which number corresponds
% to which stage can be found in the Cybathalon documentation).
% 
% Provides a graphical interface similar to the one used for the
% calibration phase.
% 
% Author: Alejandro González Rogel (s4805550)
%         Marzieh Borhanazad (s4542096)
%         Ankur Ankan (s4753828)
% Forked from https://github.com/jadref/buffer_bci
%----------------------------------------------------------------------

configureExp;

udpr = dsp.UDPReceiver('LocalIPPort',gamePortStage,'MessageDataType','int8');
% To prevent the loss of packets, call the |setup| method
% on the object before the first call to the |step| method.
% Here I just do the first step.
step(udpr);

if ( ~exist('epochFeedbackTrialDuration') || isempty(epochFeedbackTrialDuration) )
  epochFeedbackTrialDuration=trialDuration;
end;


rtbDuration=.5; %.5s between commands

cybathalon = struct('host','localhost','port',gamePortInst,'player',1,...
                    'cmdlabels',{{'jump' 'slide' 'speed' 'rest'}},'cmddict',[2 3 1 99],...
						  'cmdColors',[.6 0 .6;.6 .6 0;0 .5 0;.3 .3 .3]',...
                    'socket',[],'socketaddress',[]);
% open socket to the cybathalon game
[cybathalon.socket]=javaObject('java.net.DatagramSocket'); % create a UDP socket
cybathalon.socketaddress=javaObject('java.net.InetSocketAddress',cybathalon.host,cybathalon.port);
cybathalon.socket.connect(cybathalon.socketaddress); % connect to host/port
connectionWarned=0;

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
theta=linspace(0,2*pi,nSymbs+1) + pi/2; % 1st post=N
theta=theta(1:end-1);
stimPos=[cos(theta);sin(theta)];
for hi=1:nSymbs; 
  % set tgt to the color of that part of the game
  h(hi)=rectangle('curvature',[1 1],'position',[stimPos(:,hi)-stimRadius/2;stimRadius*[1;1]],...
                  'facecolor',cybathalon.cmdColors(:,hi));

  if ( ~isempty(symbCue) ) % cue-text
      set(fig,'Units','pixel');wSize=get(fig,'position');set(fig,'units','normalized');% win size in pixels
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

%Create a text object with no text in it, center it, set font and color
set(fig,'Units','pixel');wSize=get(fig,'position');set(fig,'units','normalized');% win size in pixels
txthdl = text(mean(get(ax,'xlim')),mean(get(ax,'ylim')),' ',...
				  'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle',...
				  'fontunits','pixel','fontsize',.05*wSize(4),...
				  'color',txtColor,'visible','off');

set(txthdl,'string', 'Click mouse when ready', 'visible', 'on'); drawnow;
waitforbuttonpress;
set(txthdl,'visible', 'off'); drawnow;

% play the stimulus
sendEvent('stimulus.testing','start');
% initialize the state so don't miss classifier prediction events
state=[]; 
endTesting=false; dvs=[];
prevStage=[];
prevAction = [];
endCont = 0;
stageCont = 0;
toDelete = 0;
startStage = true;

for si=1:max(100000,nSeq);

  if ( ~ishandle(fig) || endTesting ) break; end;
    
  %set(h(tgtSeq(:,si)>0),'facecolor',tgtColor);
  set(h(end),'facecolor',tgtColor); % green fixation indicates trial running
  drawnow;% expose; % N.B. needs a full drawnow for some reason

 % event-classifier, so send the event which triggers to classify this data-block
 sendEvent('classifier.apply','now'); % tell the classifier to apply from now

  trlStartTime=getwTime();
  ev=sendEvent('stimulus.classification_im','start');
  state=buffer('poll'); % Ensure we ignore any predictions before the trial start  
  if( verb>0 )
	 fprintf(1,'Waiting for predictions after: (%d samp, %d evt)\n',...
				state.nSamples,state.nEvents);
  end;

    sleepSec(epochFeedbackTrialDuration); 
	 % wait for classifier prediction event
	 [devents,state,nevents,nsamples]=buffer_newevents(buffhost,buffport,state,'classifier_im.prediction',[],2000);

  trlEndTime=getwTime();
  
  % do something with the prediction (if there is one), i.e. give feedback
  if( isempty(devents) ) % extract the decision value
    fprintf(1,'Error! no predictions after %gs, continuing (%d samp, %d evt)\n',trlEndTime-trlStartTime,state.nSamples,state.nEvents);
    set(h(end),'facecolor',bgColor);
    set(h(end),'facecolor',fbColor); % fix turns blue to show now pred recieved
    drawnow;
  else
	 if ( any([devents.sample]<ev.sample) ) % check for escaping predictions
		warning('prediction from before the trial start!');
	 end
	 fprintf(1,'Prediction after %gs : %s',trlEndTime-trlStartTime,ev2str(devents(end)));
    dv = devents(end).value;
    if ( numel(dv)==1 )
      if ( dv>0 && dv<=nSymbs && isinteger(dv) ) % dvicted symbol, convert to dv equivalent
        tmp=dv; dv=zeros(nSymbs,1); dv(tmp)=1;
      else % binary problem, convert to per-class
        dv=[dv -dv];
      end
    end    
    % give the feedback on the predicted class
    prob=exp((dv-max(dv))); prob=prob./sum(prob); % robust soft-max prob computation
    if ( verb>=0 ) 
		fprintf('%d) dv:[%s]\tPr:[%s]\n',ev.sample,sprintf('%5.4f ',dv),sprintf('%5.4f ',prob));
    end;  
    [ans,predTgt]=max(dv); % prediction is max classifier output
    set(h(end),'facecolor',bgColor);
    set(h(predTgt),'facecolor',fbColor);
    drawnow;
    sendEvent('stimulus.predTgt',predTgt);
    
    % Get current stage of the game
        % Get current stage of the game
    actStage=step(udpr);
    if startStage
        step(udpr);
        step(udpr);
        step(udpr);
        step(udpr);
        startStage = false;
    end
    
    if isempty(actStage)
        actStage = prevStage;
        endCont = endCont + 1;
    else
        endCont = 0;
        toDelete = 0;
    end
    prevStage = actStage;
    
	try;
		cybathalon.socket.send(javaObject('java.net.DatagramPacket',uint8([10*cybathalon.player+cybathalon.cmddict(predTgt) 0]),1));
    %if predTgt == 4
    %    sendEvent('stimulus_errp.target',0==actStage);
    %end
    if predTgt == 3
        % If we repeat an action in the same platform in a stage different
        % than 0 then we do not account for that because the game does not
        % show any state transition
        if isempty(prevAction) || prevAction~=predTgt || endcont == 0 || actStage==0
            sendEvent('stimulus_errp.target',1==actStage);
            toDelete = toDelete + 1;
        end
    end
    if predTgt == 1
        if isempty(prevAction) || prevAction~=predTgt || endcont == 0 || actStage==0
        sendEvent('stimulus_errp.target',2==actStage);
        toDelete = toDelete + 1;
        end
    end
    if predTgt == 2
                if isempty(prevAction) || prevAction~=predTgt || endcont == 0 || actStage==0

        sendEvent('stimulus_errp.target',3==actStage);
        toDelete = toDelete + 1;
                end
    end
     catch;
		if ( connectionWarned<10 )
		  connectionWarned=connectionWarned+1;
		  warning('Error sending to the Cybathalon game.  Is it running?\n');
		end
    end
     
    prevAction = predTgt;
     
		% now wait a little to give some RTB time
	 drawnow;
	 sleepSec(rtbDuration);
	 set(h(predTgt),'facecolor',cybathalon.cmdColors(:,predTgt));
	 set(h(end),'facecolor',bgColor); % clear the feedback

    if endCont>=wait_end
        sendEvent('stimulus_errp.target', - toDelete-1);    % This extra -1 is to delete this event too
        stageCont = stageCont + 1;
        endCont = 0;
        if stageCont >= numStages
            endTesting = true;
            pause(2)    % So the signal processor can finish anything it is doing
        else
            % Create new stage
            stage  =[];
            %tmp = [1 2 3];
            %for i=1:2
            %    stage = [stage, tmp(randperm(3))];
            %end
            tmp = [1 2 3];
            for i=1:sizeStage
                stage = [stage, [0], tmp(randperm(3))];
            end
            % Save previous stage to history
            fid1 = fopen(fullfile(cybathalon_path,'level.csv'),'r'); %# open csv file for reading
            fid2 = fopen(fullfile(cybathalon_path,'level_history.csv'),'a'); %# open new csv file
            line = fgets(fid1); %# read line by line
            fprintf(fid2,'%s',line); %# write the line to the new file

            fclose(fid1);
            fclose(fid2);
            
            % Write to file
            fileID = fopen(fullfile([pwd '\..\..\..\BrainRunners\CybathlonBrainRunnersTraining1.225\Win64\'],'level.csv'),'w');
            for i=1:length(stage)-1
                fprintf(fileID,'%o;',stage(i));
            end
            fprintf(fileID,'%o',stage(end));
            fclose(fileID);
            set(txthdl,'string', {['Stage ' num2str(stageCont) ' is over.'],...
                'Take a rest and prepare next stage.'}, 'visible', 'on'); drawnow;
            waitforbuttonpress;
            set(txthdl,'string', '', 'visible', 'on'); drawnow;
            
            startStage = true;
            toDelete = 0;
        end
    end
   
	 
  end % if classifier prediction  
  drawnow;
  
end % loop over sequences in the experiment
% release listening port
release(udpr)
% end training marker
sendEvent('stimulus.testing','end');

if ( ishandle(fig) ) % thanks message
set(txthdl,'string',{'That ends the testing phase.','Thanks for your patience'}, 'visible', 'on', 'color',[0 1 0]);
pause(3);
close(fig)
end
