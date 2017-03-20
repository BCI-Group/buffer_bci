%----------------------------------------------------------------------
% Offers a graphical interface from which we can select the phase of the
% pipeline we want to do next.
%
% Author: Alejandro González Rogel (s4805550)
%         Marzieh Borhanazad (s4542096)
%         Ankur Ankan (s4753828)
% Forked from https://github.com/jadref/buffer_bci
%----------------------------------------------------------------------
% Load all variables
configureExp;
% create the control window and execute the phase selection loop
contFig=figure(1);
set(contFig,'name','BCI Controller: Selection screen','color',winColor);
axes('position',[0 0 1 1],'visible','off','xlim',[0 1],'ylim',[0 1],'nextplot','add');
set(contFig,'Units','pixel');wSize=get(contFig,'position');
fontSize = .05*wSize(4);
%        Instruct String          Phase-name
menustr={'0) EEG IM'            'eegviewer_im';
    '1) Practice IM'            'practice_im';
    '2) Calibrate IM'           'calibrate_im';
    '3) Train IM Classifier'    'train_im';
    '---------' '';
    '4) EGG ErrP'               'eegviewer_errp';
    '5) Calibrate ErrP'    'calibrate_errp';
    '6) Train ErrP Classifier'    'train_errp';
    '' '';
    'a) Cybathalon Control'   'play_cybathalon';
    '' '';
    'q) quit'                'exit';
    };
txth=text(.25,.5,menustr(:,1),'fontunits','pixel','fontsize',.05*wSize(4),...
    'HorizontalAlignment','left','color',[1 1 1]);
ph=plot(1,0,'k'); % BODGE: point to move around to update the plot to force key processing
% install listener for key-press mode change
set(contFig,'keypressfcn',@(src,ev) set(src,'userdata',char(ev.Character(:))));
set(contFig,'userdata',[]);
drawnow; % make sure the figure is visible
%end
subject='test';

sendEvent('experiment.im','start');
% Main loop
while (ishandle(contFig))
    set(contFig,'visible','on');
    if ( ~ishandle(contFig) ) break; end;
    
    phaseToRun=[];
    if ( ~exist('OCTAVE_VERSION','builtin') && ~isempty(get(contFig,'tag')) )
        uiwait(contFig);
        if ( ~ishandle(contFig) ) break; end;
        info=guidata(contFig);
        subject=info.subject;
        phaseToRun=lower(info.phaseToRun);
    else % give time to process the key presses
        % BODGE: move point to force key-processing
        fprintf('.');set(ph,'ydata',rand(1)*.01); drawnow;
        if ( ~ishandle(contFig) ) break; end;
    end
    
    % Process any key-presses
    modekey=get(contFig,'userdata');
    if ( ~isempty(modekey) )
        fprintf('key=%s\n',modekey);
        phaseToRun=[];
        if ( ischar(modekey(1)) )
            ri = strmatch(modekey(1),menustr(:,1)); % get the row in the instructions
            if ( ~isempty(ri) )
                phaseToRun = menustr{ri,2};     % Map key to phase to run
            elseif ( any(strcmp(modekey(1),{'q','Q'})) )
                break;
            end
        end
        set(contFig,'userdata',[]);
    end
    
    if ( isempty(phaseToRun) ) pause(.3); continue; end;
    
    fprintf('Start phase : %s\n',phaseToRun);
    set(contFig,'visible','off');drawnow;
    % Check which phase to run
    switch phaseToRun;
        
        %------------------------------------------------------------------
        case 'eegviewer_im';
            sendEvent('subject',subject);
            sendEvent(phaseToRun,'start');
            sendEvent('startPhase.cmd',phaseToRun); % tell sig-proc what to do
            % wait until capFitting is done
            while (true) % N.B. use a loop as safer and matlab still responds on windows...
                [devents]=buffer_newevents(buffhost,buffport,[],...
                    phaseToRun,'end',1000); % wait until finished
                drawnow;
                if ( ~isempty(devents) ) break; end;
            end
            
            %--------------------------------------------------------------
        case 'practice_im';
            sendEvent('subject',subject);
            sendEvent(phaseToRun,'start');
            onSeq=nSeq; nSeq=nSeq_Prac; % override sequence number
            try
                imCalibrateStimulusIM;
            catch
                le=lasterror;fprintf('ERROR Caught:\n %s\n%s\n',...
                    le.identifier,le.message);
                sendEvent(phaseToRun,'end');
                nSeq=onSeq;
            end
            nSeq=onSeq; %Back to normal again
            sendEvent(phaseToRun,'end');
            
            %--------------------------------------------------------------
        case {'calibrate_im'};
            sendEvent('subject',subject);
            sendEvent(phaseToRun,'start');
            sendEvent('startPhase.cmd',phaseToRun);
            try
                imCalibrateStimulusIM;
            catch
                le=lasterror;fprintf('ERROR Caught:\n %s\n%s\n',...
                    le.identifier,le.message);
                sendEvent(phaseToRun,'end');
            end
            
            %--------------------------------------------------------------
        case {'train_im'};
            sendEvent('subject',subject);
            sendEvent(phaseToRun,'start');
            sendEvent('startPhase.cmd',phaseToRun);
            try
                buffer_newevents(buffhost,buffport,[],phaseToRun,'end'); % wait until finished
            catch
                le=lasterror;fprintf('ERROR Caught:\n %s\n%s\n',...
                    le.identifier,le.message);
                sendEvent(phaseToRun,'end');
            end
            
            %--------------------------------------------------------------
        case 'eegviewer_errp';
            sendEvent('subject',subject);
            sendEvent(phaseToRun,'start');
            sendEvent('startPhase.cmd',phaseToRun);
            % wait until capFitting is done
            while (true)
                [devents]=buffer_newevents(buffhost,buffport,[],...
                    phaseToRun,'end',1000); % wait until finished
                drawnow;
                if ( ~isempty(devents) ) break; end;
            end
            
            %--------------------------------------------------------------
        case {'calibrate_errp'};
            sendEvent('subject',subject);
            sendEvent(phaseToRun,'start');
            sendEvent('startPhase.cmd',phaseToRun); % Run the SigProc for the ErrP calibration
            pause(1)  % If the events are produced at the same time
                      % SigProcBufferIM won't recognice the second one
            sendEvent('startPhase.cmd','classify_im'); % Run the SigProc for the IM classifier
            try
                % run the main cybathalon control
                imPlayGame_trainErrP;
            catch
                le=lasterror;fprintf('ERROR Caught:\n %s\n%s\n',...
                    le.identifier,le.message);
                sendEvent(phaseToRun,'end');
            end
            
            
            %--------------------------------------------------------------
        case {'train_errp'};
            sendEvent('subject',subject);
            sendEvent(phaseToRun,'start');
            sendEvent('startPhase.cmd',phaseToRun);
            try
                buffer_newevents(buffhost,buffport,[],phaseToRun,'end'); % wait until finished
            catch
                le=lasterror;fprintf('ERROR Caught:\n %s\n%s\n',...
                    le.identifier,le.message);
                sendEvent(phaseToRun,'end');
            end
            %--------------------------------------------------------------
        case {'play_cybathalon'};
            sendEvent('subject',subject);
            sendEvent(phaseToRun,'start');
            sendEvent('startPhase.cmd','classify_errp'); % Run the SigProc for the ErrP calibration
            pause(1)  % If the events are produced at the same time
                      % SigProcBufferIM won't recognice the second one
            sendEvent('startPhase.cmd','classify_im'); % Run the SigProc for the IM classifier
            
            try
                % run the main cybathalon control
                imPlayGame;
            catch
                le=lasterror;fprintf('ERROR Caught:\n %s\n%s\n',...
                    le.identifier,le.message);
                sendEvent(phaseToRun,'end');
            end
            
            %--------------------------------------------------------------
        case {'quit','exit'};
            % shut down signal proc
            sendEvent('startPhase.cmd',phaseToRun);
            break;
            
    end
end

% give thanks
uiwait(msgbox({'Thank you for participating in our experiment.'},'Thanks','modal'),10);
