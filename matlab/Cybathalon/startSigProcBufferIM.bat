call ..\..\utilities\findMatlab.bat
if %ismatlab%==1 (
  start "Matlab" /b %matexe% -r "configureExp;imSigProcBufferIM('epochEventType','stimulus_im.target','freqband',[7 8 28 29],'clsfr_type','ersp','trlen_ms',trlen_ms,'calibrateOpts',calibrateOpts,'trainOpts',trainOpts,'contFeedbackOpts',contFeedbackOpts,'epochFeedbackOpts',epochFeedbackOpts,'useGUI',0);quit;" %matopts%
) else (
echo configureExp;imSigProcBufferIM^('epochEventType','stimulus_im.target','freqband',[7 8 28 29],'clsfr_type','ersp','trlen_ms',trlen_ms,'calibrateOpts',calibrateOpts,'trainOpts',trainOpts,'contFeedbackOpts',contFeedbackOpts,'epochFeedbackOpts',epochFeedbackOpts,'useGUI',0^);quit; | %matexe% %matopts%
)
