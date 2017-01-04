call ..\..\utilities\findMatlab.bat
if %ismatlab%==1 (
  start "Matlab" /b %matexe% -r "configureExp;imSigProcBufferErrP('epochEventType','stimulus_errp.target','freqband',[0.5 1 9.5 10],'clsfr_type','erp','trlen_ms',trlen_ms_ErrP,'calibrateOpts',calibrateOpts,'trainOpts',trainOpts,'contFeedbackOpts',contFeedbackOpts,'epochFeedbackOpts',epochFeedbackOpts);quit;" %matopts%
) else (
echo configureExp;imSigProcBufferErrP^('epochEventType','stimulus_errp.target','freqband',[0.5 1 9.5 10],'clsfr_type','erp','trlen_ms',trlen_ms_ErrP,'calibrateOpts',calibrateOpts,'trainOpts',trainOpts,'contFeedbackOpts',contFeedbackOpts,'epochFeedbackOpts',epochFeedbackOpts^);quit; | %matexe% %matopts%
)
