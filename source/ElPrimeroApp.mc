using Toybox.Application;

class ElPrimeroApp extends Application.AppBase {

    var mView = null;

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state) {
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
    }

    // Return the initial view of your application here
    function getInitialView() {
        mView = new ElPrimeroView();
        return [ mView ];
    }

    function onSettingsChanged() {
        if (mView == null || mView.mState == null) {
            return;
        }
        mView.mState.readSettings();
        WatchUi.requestUpdate();
    }

}