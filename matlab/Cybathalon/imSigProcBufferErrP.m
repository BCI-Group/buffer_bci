function []=imSigProcBufferErrP(varargin)
%----------------------------------------------------------------------
% Controlls for all those phases that require brain signal processing and
% are related to the Error Related Potentials signal processing.
%
% This function will remain in a contant loop until an exit event is
% captures. Until that time, it continuously looks for events that indicate
% the start of a new phase of the pipeline and acts according to that.
%
%
% Trigger events: (type,value)
%  (startPhase.cmd,eegviewer_errp)  -- show the live signal viewer
%  (startPhase.cmd,calibrate_errp)  -- start calibration phase processing.
%                                 The data data will be saved and labelled 
%                                 with the value of this event.
%                                 N.B. the event type used to define an
%                                 epoch is given in the option:
%                                        epochEventType
%  (startPhase.cmd,train_errp)      -- train a classifier based on the saved
%                                   calibration data
%  (startPhase.cmd,classify_errp)    -- start test phase, i.e. on-line
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
%  (classifier_errp.prediction,val)  -- classifier prediction events.
%                                 val is the classifier decision value
%
% Options:
%   phaseEventType -- 'str' event type which says start a new phase                 ('startPhase.cmd')
%   epochEventType -- 'str' event type which indicates start of calibration epoch.  ('stimulus_errp.target')
%                     This event's value is used as the class label
%   testepochEventType -- 'str' event type which start of data to generate a prediction for.  ('stimulus.classification_errp')
%   trlen_ms       -- [int] trial length in milliseconds.  This much data after each  
%                     epochEvent saved to train the classifier
%   freqband       -- [float 4x1] frequency band to use the the spectral filter during
%                     pre-processing
%   calibrateOpts  -- {cell} addition options to pass to the calibration routine
%                     SEE: buffer_waitData for information on th options available
%   trainOpts      -- {cell} cell array of additional options to pass to the classifier trainer, e.g.
%                       'trainOpts',{'width_ms',1000} % sets the welch-window-width to 1000ms
%                     SEE: buffer_train_clsfr for a list of options available
%
%   capFile        -- [str] filename for the channel positions                         ('1010')
%   verb           -- [int] verbosity level                                            (1)
%   buffhost       -- str, host name on which ft-buffer is running                     ('localhost')
%   buffport       -- int, port number on which ft-buffer is running                   (1972)
%   epochPredFilt  -- [float/str/function_handle] prediction filter for smoothing the
%                      epoch output classifier.
%
%
% Author: Alejandro Gonz�lez Rogel (s4805550)
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
    'erpEventType',[],'erpMaxEvents',[],'erpOpts',{{}},...
    'clsfr_type','erp','trlen_ms',650,'freqband',[0.5 1 9.5 10],...
    'calibrateOpts',{{}},'trainOpts',{{}},...
    'epochPredFilt',[],...
    'capFile',[],...
    'subject','test','verb',1,'buffhost',[],'buffport',[],'timeout_ms',500,'wait_end',5);
opts=parseOpts(opts,varargin);
if ( ~iscell(opts.erpOpts) ) opts.erpOpts={opts.erpOpts}; end;
if ( ~iscell(opts.trainOpts))opts.trainOpts={opts.trainOpts}; end;

thresh=[.5 3];  badchThresh=.5;   overridechnms=0;
capFile=opts.capFile;
if( isempty(capFile) )
    [fn,pth]=uigetfile(fullfile(mdir,'..','../resources/caps/*.txt'),'Pick cap-file');
    if ( isequal(fn,0) || isequal(pth,0) ) capFile='cap_tmsi_mobita_ErrP.txt';
    else                                   capFile=fullfile(pth,fn);
    end; % 1010 default if not selected
end
if ( ~isempty(strfind(capFile,'1010.txt')) ) overridechnms=0; else overridechnms=1; end; % force default override

if ( isempty(opts.epochEventType) )     opts.epochEventType={'stimulus_errp.target'}; end;
if ( isempty(opts.testepochEventType) ) opts.testepochEventType='stimulus.classification_errp'; end;

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

dname_errp = 'training_data_ErrP';
cname_errp = 'clsfr_ErrP';

% main loop waiting for commands and then executing them
nevents=hdr.nEvents; nsamples=hdr.nsamples;
state=struct('nevents',nevents,'nsamples',nsamples);
phaseToRun=[]; clsSubj=[]; trainSubj=[];
while ( true )

    if ( ~isempty(phaseToRun) ) state=[]; end
        
    % wait for a phase control event
    if ( opts.verb>0 ) fprintf('%d) Waiting for phase command\n',nsamples); end;
    [devents,state,nevents,nsamples]=buffer_newevents(opts.buffhost,...
        opts.buffport,state,{opts.phaseEventType 'subject'},[],opts.timeout_ms);
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
    sendEvent(lower(phaseToRun),'start'); % mark start/end testing
    
    switch lower(phaseToRun);
        
        %---------------------------------------------------------------------------------
        case {'eegviewer_errp'};
            eegViewer(opts.buffhost,opts.buffport,'capFile',capFile,'overridechnms',overridechnms);
        %---------------------------------------------------------------------------------
        
        case {'calibrate_errp'};
            state = [];
            [traindata,traindevents,state]=buffer_waitData(opts.buffhost,...
                 opts.buffport,[],'startSet',opts.epochEventType,'exitSet',...   % The event to catch is stimulus_errp.target in imPlayGame
                 {'stimulus.testing' 'end'},'verb',opts.verb,...
                 'trlen_ms',opts.trlen_ms,opts.calibrateOpts{:});
            
            % ensure events are processed in *temporal* order
            [ans,eventsorder]=sort([traindevents.sample],'ascend');
            traindevents=traindevents(eventsorder);
            traindata = traindata(eventsorder);
            
            % remove useless data
            elementsDeleted = 0;
            i = 1;
            while true
                index = i - elementsDeleted;
                if index==length(traindevents)
                    break
                end
                type = traindevents(index).type;
                value = traindevents(index).value;
                if strcmp(type, opts.epochEventType) && value < 0
                    value = -value - 1; % We added -1 before to recognize these events
                    range = ((index-value):index);   % Delete last opts.wait_end events after an event that indicates end of stage.
                    elementsDeleted = elementsDeleted + (value + 1);
                    traindevents(range)=[];
                    traindata(range)=[];
                end
                i = i + 1;
            end
             
            %remove exit event
            mi=matchEvents(traindevents,{'stimulus.testing'},'end');
            traindevents(mi)=[];
            traindata(mi)=[];

            fname=[dname_errp '_' subject '_' datestr];
            fprintf('Saving %d epochs to : %s\n',numel(traindevents), fname);
            save([fname '.mat'],'traindata','traindevents','hdr');
            
            trainSubj=subject;
        %---------------------------------------------------------------------------------
        case {'train_errp'};
            %try
            if ( ~isequal(trainSubj,subject) || ~exist('traindata','var') )
                fname=[dname_errp '_' subject '_' datestr];
                fprintf('Loading training data from : %s\n',fname);
                if ( ~(exist([fname '.mat'],'file') || exist(fname,'file')) )
          warning(['We could not find a data file with the name: ' fname ...
              '. Please, choose the desired file']);
            [fn,pth]=uigetfile('.','Pick ErrP data file'); 
            if ( isequal(fn,0) || isequal(pth,0) )
                error('No ErrP data selected.')
                break;
            else
                fname=fullfile(fn);
            end;
                end
                load(fname);
                trainSubj=subject;
            end;
            if ( opts.verb>0 ) fprintf('%d epochs\n',numel(traindevents)); end;
            
%             [clsfr,res]=buffer_train_erp_clsfr(traindata,traindevents,...
%                 hdr,'spatialfilter','car', 'freqband',opts.freqband,...
%                 'badchrm',1,'badtrrm',1,'capFile',capFile,...
%                 'overridechnms',overridechnms,'verb',opts.verb, opts.trainOpts{:});
            
%            for i=1:size(traindata,1)
                %tmp1 = traindata(i).buf(1,:);
                %tmp2 = traindata(i).buf(1,:);
                %tmp3 = traindata(i).buf(1,:);
%                traindata(i).buf(1,:) = traindata(i).buf(5,:);
%                traindata(i).buf(2,:) = traindata(i).buf(9,:);
%                traindata(i).buf(3,:) = traindata(i).buf(11,:);
            %    traindata(i).buf(4:32,:) = [];
%            end

            [clsfr]=buffer_train_erp_clsfr(traindata,traindevents,...
                hdr, 'freqband',opts.freqband,...
                'capFile',capFile,...
                'verb',opts.verb, opts.trainOpts{:});
            
            clsSubj=subject;
            fname=[cname_errp '_' subject '_' datestr];
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
        case {'classify_errp'};
            %try
                if ( ~isequal(clsSubj,subject) || ~exist('clsfr','var') )
                    clsfrfile = [cname_errp '_' subject '_' datestr];
                    if ( ~(exist([clsfrfile '.mat'],'file') || exist(clsfrfile,'file')) )
                        		  warning(['We could not find a classifier with the name: ' clsfrfile ...
              '. Please, choose the desired classifier']);
            [fn,pth]=uigetfile('.','Pick Error Related signal classifier'); 
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
                
                event_applyClsfrErrp(clsfr,'startSet',{'stimulus_errp.predict'},...
                    'predEventType','classifier_errp.prediction',... 
                    'endType',{'testing','test','epochfeedback','eventfeedback'},...
                    'verb',opts.verb,...
                    'trlen_ms', opts.trlen_ms);
                
                
%             catch
%                 fprintf('Error in : %s',phaseToRun);
%                 le=lasterror;fprintf('ERROR Caught:\n %s\n%s\n',le.identifier,le.message);
%                 if ( ~isempty(le.stack) )
%                     for i=1:numel(le.stack);
%                         fprintf('%s>%s : %d\n',le.stack(i).file,le.stack(i).name,le.stack(i).line);
%                     end;
%                 end
%                 msgbox({sprintf('Error in : %s',phaseToRun) 'OK to continue!'},'Error');
%                 sendEvent('testing','end');
%             end
            
        case {'quit','exit'};
            break;
            
        otherwise;
            warning(sprintf('Unrecognised experiment phase ignored! : %s',phaseToRun));
            
    end
    if ( opts.verb>0 ) fprintf('Finished : %s @ %5.3fs\n',phaseToRun,getwTime()-ptime); end;
    sendEvent(phaseToRun,'end');

    
end
