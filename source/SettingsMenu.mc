import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! On-watch settings: one entry per setting, each opening a list of options.
class SettingsMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({:title => Rez.Strings.SettingsTitle});
        for (var i = 0; i < Settings.KEYS.size(); i++) {
            var key = Settings.KEYS[i];
            addItem(new WatchUi.MenuItem(Settings.title(key), Settings.currentLabel(key), key, null));
        }
    }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var key = item.getId() as String;
        var options = Settings.options(key);
        var current = Settings.getNumber(key);
        var menu = new WatchUi.Menu2({:title => Settings.title(key)});
        var focus = 0;
        for (var i = 0; i < options.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(options[i][0], null, options[i][1], null));
            if (options[i][1] == current) {
                focus = i;
            }
        }
        menu.setFocus(focus);
        WatchUi.pushView(menu, new SettingOptionDelegate(key, item), WatchUi.SLIDE_LEFT);
    }
}

class SettingOptionDelegate extends WatchUi.Menu2InputDelegate {

    private var _key as String;
    private var _parentItem as WatchUi.MenuItem;

    function initialize(key as String, parentItem as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _key = key;
        _parentItem = parentItem;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        Settings.setNumber(_key, item.getId() as Number);
        _parentItem.setSubLabel(item.getLabel());
        (Application.getApp() as WatchFaceApp).onSettingsChanged();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
