%----------------------------------------------------------------------
% One-Time initialization code
% guard to not run the slow one-time-only config code every time...
if ( ~exist('configRun','var') || isempty(configRun) ) 

  % setup the paths
  run ../utilities/initPaths.m;

  buffhost='localhost';buffport=1972;
  % wait for the buffer to return valid header information
  hdr=[];
  while( isempty(hdr) || ~isstruct(hdr) || (hdr.nchans==0) ) %wait for the buffer to contain valid data
	 try 
		hdr=buffer('get_hdr',[],buffhost,buffport); 
	 catch
		hdr=[];
		fprintf('Invalid header info... waiting.\n');
	 end;
	 pause(1);
  end;

  % set the real-time-clock to use
  initgetwTime;
  initsleepSec;

  if ( exist('OCTAVE_VERSION','builtin') ) 
	 page_output_immediately(1); % prevent buffering output
	 if ( ~isempty(strmatch('qt',available_graphics_toolkits())) )
		graphics_toolkit('qt'); 
	 elseif ( ~isempty(strmatch('qthandles',available_graphics_toolkits())) )
		graphics_toolkit('qthandles'); 
	 elseif ( ~isempty(strmatch('fltk',available_graphics_toolkits())) )
		graphics_toolkit('fltk'); % use fast rendering library
	 end
  end

  % One-time configuration has successfully completed
  configRun=true;
end
%----------------------------------------------------------------------

%----------------------------------------------------------------------
% Application specific config
verb         =1; % verbosity level for debug messages, 1=default, 0=quiet, 2=very verbose
buffhost     ='localhost';
buffport     =1972; % Port to connect to the EEG buffer
gamePort     =6666; % Port to connect to the game (just valid during training).
nSymbs       =3; % E,N,W,S for 4 outputs, N,W,E  for 3 outputs
symbCue      ={'Feet' 'Left-Hand' 'Right-Hand'};
baselineClass='99 Rest'; % if set, treat baseline phase as a separate class to classify
nSeq         =15*nSymbs; % 15 examples of each target
nSeq_Prac    =2*nSymbs; % Number of item to practice with in the Practice phase

epochDuration     =1.5;
trialDuration     = 3; % epochDuration*3; % = 4.5s trials
baselineDuration  =epochDuration;   % = 1.5s baseline
intertrialDuration=epochDuration;   % = 1.5s post-trial
feedbackDuration  = 0.1; %epochDuration;

axLim        =[-1.5 1.5]; % size of the display axes
winColor     =[0 0 0]; % window background color
bgColor      =[.5 .5 .5]; % background/inactive stimuli color
fixColor     =[1 0 0]; % fixitation/get-ready cue point color
tgtColor     =[0 1 0]; % target color
fbColor      =[0 0 1]; % feedback color
txtColor     =[1 1 1]; % color of the cue text

% Calibration/data-recording options
offset_ms     = [250 250]; % give .25s for user to start/finish
trlen_ms      = epochDuration*1000; % how often to run the classifier of imaginary movement.
trlen_ms_ErrP      = 650; % how much time we collect data for the analysis of ErrP
calibrateOpts ={'offset_ms',offset_ms};
adaptHalfLife_ms = 10*1000; %10s

% classifier training options
freqband_im = [7 8 28 29];
freqband_errp = [0.5 1 9.5 10];
welch_width_ms = 250; % width of welch window => spectral resolution
step_ms       = welch_width_ms/2;% N.B. welch defaults=.5 window overlap, use step=width/2 to simulate
trialadaptfactor = exp(log(.5)/(adaptHalfLife_ms/trlen_ms)); % adapt rate when apply per-trial
contadaptfactor = exp(log(.5)/(adaptHalfLife_ms/welch_width_ms)); % adapt rate when apply per welch-win

%trainOpts={'width_ms',welch_width_ms,'badtrrm',0}; % default: 4hz res, stack of independent one-vs-rest classifiers
%trainOpts={'width_ms',welch_width_ms,'badtrrm',0,'spatialfilter','wht','objFn','mlr_cg','binsp',0,'spMx','1vR'}; % whiten + direct multi-class training
trainOpts={'width_ms',welch_width_ms,'badtrrm',0,'spatialfilter','trwht','adaptivespatialfilt',trialadaptfactor,'objFn','mlr_cg','binsp',0,'spMx','1vR'}; % adaptive-whiten + direct multi-class training
