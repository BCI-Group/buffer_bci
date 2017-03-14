function []=imSigProcBufferIM(varargin)
%----------------------------------------------------------------------
% Controlls for all those phases that require brain signal processing and
% are related to the imaginary movement signal processing.
%
% This function will remain in a contant loop until an exit event is
% captures. Until that time, it continuously looks for events that indicate
% the start of a new phase of the pipeline and acts according to that.
%
% Trigger events: (type,value)
%  (startPhase.cmd,eegviewer_im)  -- show the live signal viewer
%  (startPhase.cmd,practice_im)  -- Allows for practice of the Imaginary
%                                   movement calibration phase
%  (startPhase.cmd,calibrate_im)  -- start calibration phase processing.
%                                 The data data will be saved and labelled 
%                                 with the value of this event.
%                                 N.B. the event type used to define an
%                                 epoch is given in the option:
%                                        epochEventType
%  (startPhase.cmd,train_im)      -- train a classifier based on the saved
%                                   calibration data
%  (startPhase.cmd,classify_im)    -- start test phase, i.e. on-line
%                                   prediction generation
%                                 This type of testing will generate
%                                   1 prediction event for each 
%                                   epoch event.  
%                                 NB. The event to predict for is given in
%                                   option: testepochEventType
%                                  (FYI: this uses the function event_applyClsfr)
%  (startPhase.cmd,exit)       -- stop everything
%
% Prediction Events
%  During the testing phase the classifier will send predictions with the type
%  (classifier_im.prediction,val)  -- classifier prediction events.  
%                                 val is the classifier decision value
%
% Options:
%   phaseEventType -- 'str' event type which says start a new phase                 ('startPhase.cmd')
%   epochEventType -- 'str' event type which indicates start of calibration epoch.  ('stimulus_im.target')
%                     This event's value is used as the class label
%   testepochEventType -- 'str' event type which start of data to generate a prediction for.  ('stimulus.classification_im')
%   trlen_ms       -- [int] trial length in milliseconds.  This much data after each  (1000)
%                     epochEvent saved to train the classifier
%   freqband       -- [float 4x1] frequency band to use the the spectral filter during ([.1 .5 10 12])
%                     pre-processing
%
%   calibrateOpts  -- {cell} addition options to pass to the calibration routine
%                     SEE: buffer_waitData for information on th options available
%   trainOpts      -- {cell} cell array of additional options to pass to the classifier trainer, e.g.
%                       'trainOpts',{'width_ms',1000} % sets the welch-window-width to 1000ms
%                     SEE: buffer_train_clsfr for a list of options available
%   epochFeedbackOpts -- {cell} cell array of additional options to pass to the epoch feedback (i.e. 
%                        event triggered) classifier
%                        SEE: event_applyClsfr for a list of options available
%                        SEE: cont_applyClsfr for a list of options available   
%
%   capFile        -- [str] filename for the channel positions                         ('1010')
%   verb           -- [int] verbosity level                                            (1)
%   buffhost       -- str, host name on which ft-buffer is running                     ('localhost')
%   buffport       -- int, port number on which ft-buffer is running                   (1972)
%   epochPredFilt  -- [float/str/function_handle] prediction filter for smoothing the 
%                      epoch output classifier.
%
%
% Author: Alejandro González Rogel (s4805550)
%         Marzieh Borhanazad (s4542096)
%         Ankur Ankan (s4753828)
% Forked from https://github.com/jadref/buffer_bci
%-------------------------------------------------------------------------
% setup the paths if needed
wb=which('buffer'); 
mdir=fileparts(mfilename('fullpath'));
if ( isempty(wb) || isempty(strfind('dataAcq',wb)) ) 
  run(fullfile(mdir,'../utilities/initPaths.m')); 
  % set the real-time-clock to use
  initgetwTime;
  initsleepSec;
end;
opts=struct('phaseEventType','startPhase.cmd',...
				'epochEventType',[],'testepochEventType',[],...
				'clsfr_type','ersp','trlen_ms',1000,'freqband_im',[7 8 28 29],...
				'calibrateOpts',{{}},'trainOpts',{{}},...
                'epochPredFilt',[],'capFile',[],...
				'subject','test','verb',1,'buffhost',[],'buffport',[],...
                'timeout_ms',500,'epochFeedbackOpts',{{}});
opts=parseOpts(opts,varargin);
if ( ~iscell(opts.trainOpts))opts.trainOpts={opts.trainOpts}; end;

capFile=opts.capFile;
if( isempty(capFile) ) 
  [fn,pth]=uigetfile(fullfile(mdir,'..','../resources/caps/*.txt'),'Pick cap-file'); 
  if ( isequal(fn,0) || isequal(pth,0) ) capFile='cap_tmsi_mobita_im.txt'; 
  else                                   capFile=fullfile(pth,fn);
  end; % 1010 default if not selected
end
if ( ~isempty(strfind(capFile,'1010.txt')) ) overridechnms=0; else overridechnms=1; end; % force default override

if ( isempty(opts.epochEventType) )     opts.epochEventType='stimulus_im.target'; end;
if ( isempty(opts.testepochEventType) ) opts.testepochEventType='stimulus.classification_im'; end;

datestr = datevec(now); datestr = sprintf('%02d%02d%02d',datestr(1)-2000,datestr(2:3)); % Date YYMMDD
subject=opts.subject;

% wait for the buffer to return valid header information
hdr=[];
while ( isempty(hdr) || ~isstruct(hdr) || (hdr.nchans==0) ) % wait for the buffer to contain valid data
  try 
    hdr=buffer('get_hdr',[],opts.buffhost,opts.buffport); 
  catch
    hdr=[];
    fprintf('Invalid header info... waiting.\n');
  end;
  pause(1);
end;

dname_im = 'training_data';
cname_im = 'clsfr';

% main loop waiting for commands and then executing them
nevents=hdr.nEvents; nsamples=hdr.nsamples;
state=struct('nevents',nevents,'nsamples',nsamples); 
phaseToRun=[]; clsSubj=[]; trainSubj=[];
while ( true )

  if ( ~isempty(phaseToRun) ) state=[]; end

  % wait for a phase control event
  if ( opts.verb>0 ) fprintf('%d) Waiting for phase command\n',nsamples); end;
  [devents,state,nevents,nsamples]=buffer_newevents(opts.buffhost,opts.buffport,state,...
																	 {opts.phaseEventType 'subject'},[],opts.timeout_ms);
  if ( numel(devents)==0 ) 
    continue;
  elseif ( numel(devents)>1 ) 
    % ensure events are processed in *temporal* order
    [ans,eventsorder]=sort([devents.sample],'ascend');
    devents=devents(eventsorder);
  end
  if ( opts.verb>0 ) fprintf('Got Event: %s\n',ev2str(devents)); end;

  % process any new buffer events
  phaseToRun=[];
  for di=1:numel(devents);
    % extract the subject info
    if ( strcmp(devents(di).type,'subject') )     
      subject=devents(di).value; 
      if ( opts.verb>0 ) fprintf('Setting subject to : %s\n',subject); end;
      continue; 
    else
      phaseToRun=devents(di).value;
      break;
    end  
  end
  if ( isempty(phaseToRun) ) continue; end;

  fprintf('%d) Starting phase : %s\n',devents(di).sample,phaseToRun);
  if ( opts.verb>0 ) ptime=getwTime(); end;
  
  switch lower(phaseToRun);
    
    %---------------------------------------------------------------------------------
   case {'eegviewer_im'};
        eegViewer(opts.buffhost,opts.buffport,'capFile',capFile,'overridechnms',overridechnms);
   %---------------------------------------------------------------------------------
   case {'calibrate_im'};
    [traindata,traindevents,state]=buffer_waitData(opts.buffhost,opts.buffport,[],'startSet',opts.epochEventType,'exitSet',{'stimulus_im.calibration' 'end'},'verb',opts.verb,'trlen_ms',opts.trlen_ms,opts.calibrateOpts{:});
    mi=matchEvents(traindevents,{'stimulus_im.calibration'},'end'); traindevents(mi)=[]; traindata(mi)=[];%remove exit event
    fname=[dname_im '_' subject '_' datestr];
    fprintf('Saving %d epochs to : %s\n',numel(traindevents),fname);
    save([fname '.mat'],'traindata','traindevents','hdr');
    trainSubj=subject;

    %---------------------------------------------------------------------------------
    case {'train_im'};
%     try
      if ( ~isequal(trainSubj,subject) || ~exist('traindata','var') )
        fname=[dname_im '_' subject '_' datestr];
        fprintf('Loading training data from : %s\n',fname);
        if ( ~(exist([fname '.mat'],'file') || exist(fname,'file')) ) 
          warning(['We could not find a data file with the name: ' fname ...
              '. Please, choose the desired file']);
            [fn,pth]=uigetfile('.','Pick imaginary movement data file'); 
            if ( isequal(fn,0) || isequal(pth,0) )
                error('No IM data selected.')
                break;
            else
                fname=fullfile(fn);
            end;
        end
        load(fname); 
        trainSubj=subject;
      end;

      trainSubj=subject;
      if ( opts.verb>0 ) fprintf('%d epochs\n',numel(traindevents)); end;
		
      [clsfr,res]=buffer_train_ersp_clsfr(traindata,traindevents,hdr,...
						   'freqband',opts.freqband_im,...
							'capFile',capFile,'overridechnms',overridechnms,'verb',opts.verb,...
							opts.trainOpts{:});
       
      clsSubj=subject;
      fname=[cname_im '_' subject '_' datestr];
      fprintf('Saving classifier to : %s\n',fname);save([fname '.mat'],'clsfr');
	%catch
      % fprintf('Error in : %s',phaseToRun);
      % le=lasterror;fprintf('ERROR Caught:\n %s\n%s\n',le.identifier,le.message);
	  	% if ( ~isempty(le.stack) )
	  	%   for i=1:numel(le.stack);
	  	% 	 fprintf('%s>%s : %d\n',le.stack(i).file,le.stack(i).name,le.stack(i).line);
	  	%   end;
	  	% end
	  	% msgbox({sprintf('Error in : %s',phaseToRun) 'OK to continue!'},'Error');
      % sendEvent('training','end');    
    %end

    %---------------------------------------------------------------------------------
   case {'classify_im'};
    try
    if ( ~isequal(clsSubj,subject) || ~exist('clsfr','var') ) 
      clsfrfile = [cname_im '_' subject '_' datestr];
      if ( ~(exist([clsfrfile '.mat'],'file') || exist(clsfrfile,'file')) ) 
		  warning(['We could not find a classifier with the name: ' clsfrfile ...
              '. Please, choose the desired classifier']);
            [fn,pth]=uigetfile('.','Pick imaginary movement classifier'); 
            if ( isequal(fn,0) || isequal(pth,0) )
                error('No classifier selected.')
                break;
            else
                clsfrfile=fullfile(fn);
            end;
	  end;
      if(opts.verb>0)fprintf('Loading classifier from file : %s\n',clsfrfile);end;
      clsfr=load(clsfrfile);
      if( isfield(clsfr,'clsfr') ) clsfr=clsfr.clsfr; end;
      clsSubj = subject;
    end;
    
    event_applyClsfr(clsfr,'startSet',opts.testepochEventType,...
							'predFilt',opts.epochPredFilt,...
							'endType',{'stimulus.testing','testing','test','epochfeedback','eventfeedback'},...
                            'endValue',{'end'},...
                            'predEventType','classifier_im.prediction',...
                            'verb',opts.verb,...
							'trlen_ms',opts.trlen_ms,...
							opts.epochFeedbackOpts{:}); % allow override with epochFeedbackOpts
	 catch
      fprintf('Error in : %s',phaseToRun);
      le=lasterror;fprintf('ERROR Caught:\n %s\n%s\n',le.identifier,le.message);
		if ( ~isempty(le.stack) )
		  for i=1:numel(le.stack);
			 fprintf('%s>%s : %d\n',le.stack(i).file,le.stack(i).name,le.stack(i).line);
		  end;
		end
      msgbox({sprintf('Error in : %s',phaseToRun) 'OK to continue!'},'Error');
    end
      
   case {'quit','exit'};
    break;
    
   otherwise;
          warning(sprintf('Unrecognised experiment phase ignored! : %s',phaseToRun));
    
  end
  if ( opts.verb>0 ) fprintf('Finished : %s @ %5.3fs\n',phaseToRun,getwTime()-ptime); end;
  sendEvent(phaseToRun,'end');
  
end
