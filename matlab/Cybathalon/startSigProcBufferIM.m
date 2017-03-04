%----------------------------------------------------------------------
% Initializes variables that will be used for the signal processor and
% calls the signal processor related to the Error Related Potential signal
% processing.
%
% Author: Alejandro González Rogel (s4805550)
%         Marzieh Borhanazad (s4542096)
%         Ankur Ankan (s4753828)
% Forked from https://github.com/jadref/buffer_bci
%----------------------------------------------------------------------
configureExp;
imSigProcBufferIM('epochEventType','stimulus_im.target','freqband_im',freqband_im,...
                   'clsfr_type','ersp','trlen_ms',trlen_ms_im,...
                   'calibrateOpts',calibrateOpts_im,'trainOpts',trainOpts_im,'timeout_ms',timeout_ms,'verb',verb);       