if ( ~exist('runConfig','var') || ~runConfig ) configureDemo; end;

% make the stimulus
fig=figure(2);clf;
set(fig,'Name','Matrix Speller','color',[0 0 0],'menubar','none','toolbar','none','doublebuffer','on');
ax=axes('position',[0.025 0.025 .975 .975],'units','normalized','visible','off','box','off',...
        'xtick',[],'xticklabelmode','manual','ytick',[],'yticklabelmode','manual',...
        'color',[0 0 0],'DrawMode','fast','nextplot','replacechildren',...
        'xlim',[-1.5 1.5],'ylim',[-1.5 1.5],'Ydir','normal');
[h,symbs]=initGrid(symbols);

% make the row/col flash sequence for each sequence
if ( ~exist('nTestRepetitions','var') ) nTestRepetitions=nRepetitions; end;
[stimSeqRow]=mkStimSeqRand(size(symbols,1),nTestRepetitions*size(symbols,1));
[stimSeqCol]=mkStimSeqRand(size(symbols,2),nTestRepetitions*size(symbols,2));

% play the stimulus
% reset the cue and fixation point to indicate trial has finished  
set(h(:),'color',[.5 .5 .5]);
sendEvent('stimulus.training','start');
state=[];
for si=1:nSeq;

  if ( ~ishandle(fig) ) break; end;
  nFlash = 0; stimSeq=zeros(size(symbols));
  set(h(:),'color',bgColor); % rest all symbols to background color
  sleepSec(interSeqDuration);
  sendEvent('stimulus.sequence','start');
  
  if( verb>0 ) fprintf(1,'Rows  '); end;
  % rows stimulus
  for ei=1:size(stimSeqRow,2);
    % record the stimulus state, needed for decoding the classifier predictions later
    nFlash=nFlash+1;
    stimSeq(stimSeqRow(:,ei)>0,:,nFlash)=true;
    % set the stimulus state
    set(h(:),'color',bgColor);
    set(h(stimSeqRow(:,ei)>0,:),'color',flashColor);
    drawnow;
    sendEvent('stimulus.rowFlash',stimSeqRow(:,ei)); % indicate this row is 'flashed'    
    sleepSec(stimDuration);
  end

  if( verb>0 ) fprintf(1,'Cols');end
  % cols stimulus
  for ei=1:size(stimSeqCol,2);
    % record the stimulus state, needed for decoding the classifier predictions later
    nFlash=nFlash+1;
    stimSeq(:,stimSeqCol(:,ei)>0,nFlash)=true;
    % set the stimulus state
    set(h(:),'color',bgColor);
    set(h(:,stimSeqCol(:,ei)>0),'color',flashColor);
    drawnow;
    sendEvent('stimulus.colFlash',stimSeqCol(:,ei)); % indicate this row is 'flashed'
    sleepSec(stimDuration);    
  end
   
  % reset the cue and fixation point to indicate trial has finished  
  set(h(:),'color',bgColor);
  drawnow;
  sleepSec(trlen_ms/1000-stimDuration+.2);  % wait long enough for classifier to finish up..
  sendEvent('stimulus.sequence','end');

  % combine the classifier predictions with the stimulus used
  % wait for the signal processing pipeline to return the sequence of epoch predictions
  if( verb>0 ) fprintf(1,'Waiting for predictions\n'); end;
  [devents,state,nevents,nsamples]=buffer_newevents(buffhost,buffport,state,'classifier.prediction',[],trlen_ms);
  %[data,devents,state]=buffer_waitData(buffhost,buffport,[],'exitSet',{trlen_ms 'classifier.prediction'});
  if ( 0 && isempty(devents) ) devents=mkEvent('prediction',randn(nFlash,1)); end; % testing code ONLY
  if ( ~isempty(devents) ) 
    % correlate the stimulus sequence with the classifier predictions to identify the most likely
    % N.B. assume last prediction is one for prev sequence  
    corr = reshape(stimSeq(:,:,1:nFlash),[numel(symbols) nFlash])*devents(end).value(:); 
    [ans,predTgt] = max(corr); % predicted target is highest correlation
  
    % show the classifier prediction
    set(h(predTgt),'color',tgtColor);
    drawnow;
    sendEvent('stimulus.prediction',symbols{predTgt});
  else
		fprintf('No prediction events recieved!');
  end
  sleepSec(feedbackDuration);
  fprintf('\n');
end % sequences
% end training marker
sendEvent('stimulus.feedback','end');
if ( ishandle(fig) )
  text(mean(get(ax,'xlim')),mean(get(ax,'ylim')),{'That ends the training phase.','Thanks for your patience'},'HorizontalAlignment','center','color',[0 1 0],'fontunits','normalized','FontSize',.1);
  pause(3);
end
