package com.newsblur.activity;

import android.app.ActionBar;
import android.content.Intent;
import android.os.Bundle;
import android.preference.PreferenceManager;
import android.app.DialogFragment;
import android.app.FragmentManager;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.Window;

import com.newsblur.R;
import com.newsblur.fragment.FolderListFragment;
import com.newsblur.fragment.LogoutDialogFragment;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.service.SyncService;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.UIUtils;
import com.newsblur.view.StateToggleButton.StateChangedListener;

public class Main extends NbActivity implements StateChangedListener, SyncUpdateFragment.SyncUpdateFragmentInterface {

	private ActionBar actionBar;
	private FolderListFragment folderFeedList;
	private FragmentManager fragmentManager;
	private SyncUpdateFragment syncFragment;
	private static final String TAG = "MainActivity";
	private Menu menu;
    private boolean isLightTheme;

	@Override
	public void onCreate(Bundle savedInstanceState) {

        PrefsUtils.checkForUpgrade(this);
        PreferenceManager.setDefaultValues(this, R.layout.activity_settings, false);

        isLightTheme = PrefsUtils.isLightThemeSelected(this);

		requestWindowFeature(Window.FEATURE_PROGRESS);
		requestWindowFeature(Window.FEATURE_INDETERMINATE_PROGRESS);
		super.onCreate(savedInstanceState);

		setContentView(R.layout.activity_main);
		setupActionBar();

		fragmentManager = getFragmentManager();
		folderFeedList = (FolderListFragment) fragmentManager.findFragmentByTag("folderFeedListFragment");
		folderFeedList.setRetainInstance(true);
		
		syncFragment = (SyncUpdateFragment) fragmentManager.findFragmentByTag(SyncUpdateFragment.TAG);
		if (syncFragment == null) {
			syncFragment = new SyncUpdateFragment();
			fragmentManager.beginTransaction().add(syncFragment, SyncUpdateFragment.TAG).commit();

            // for our first sync, don't just trigger a heavyweight refresh, do it in two steps
            // so the UI appears more quickly (per the docs at newsblur.com/api)
            if (PrefsUtils.isTimeToAutoSync(this)) {
                triggerFirstSync();
            }
		}
	}

    @Override
    protected void onResume() {
        super.onResume();

        if (PrefsUtils.isLightThemeSelected(this) != isLightTheme) {
            UIUtils.restartActivity(this);
        }

        if (PrefsUtils.isTimeToAutoSync(this)) {
            triggerRefresh();
        }
        // clear all stories from the DB, the story activities will load them.
        FeedUtils.clearStories(this);
    }

    /**
     * Triggers an initial two-phase sync, so the UI can display quickly using /reader/feeds and
     * then call /reader/refresh_feeds to get updated counts.
     */
	private void triggerFirstSync() {
        PrefsUtils.updateLastSyncTime(this);
		setProgressBarIndeterminateVisibility(true);
        setRefreshEnabled(false);
		
		final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
		intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
		intent.putExtra(SyncService.EXTRA_TASK_TYPE, SyncService.TaskType.FOLDER_UPDATE_TWO_STEP);
		startService(intent);
	}
	
	/**
     * Triggers a full, manually requested refresh of feed/folder data and counts.
     */
    private void triggerRefresh() {
        PrefsUtils.updateLastSyncTime(this);
		setProgressBarIndeterminateVisibility(true);
        setRefreshEnabled(false);

		final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
		intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
		intent.putExtra(SyncService.EXTRA_TASK_TYPE, SyncService.TaskType.FOLDER_UPDATE_WITH_COUNT);
		startService(intent);
	}

	private void setupActionBar() {
		actionBar = getActionBar();
		actionBar.setNavigationMode(ActionBar.NAVIGATION_MODE_STANDARD);
	}
	
	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);
		MenuInflater inflater = getMenuInflater();
		inflater.inflate(R.menu.main, menu);
		this.menu = menu;
		return true;
	}

	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		if (item.getItemId() == R.id.menu_profile) {
			Intent profileIntent = new Intent(this, Profile.class);
			startActivity(profileIntent);
			return true;
		} else if (item.getItemId() == R.id.menu_refresh) {
			triggerRefresh();
			return true;
		} else if (item.getItemId() == R.id.menu_add_feed) {
			Intent intent = new Intent(this, SearchForFeeds.class);
			startActivityForResult(intent, 0);
			return true;
		} else if (item.getItemId() == R.id.menu_logout) {
			DialogFragment newFragment = new LogoutDialogFragment();
			newFragment.show(getFragmentManager(), "dialog");
		} else if (item.getItemId() == R.id.menu_settings) {
            Intent settingsIntent = new Intent(this, Settings.class);
            startActivity(settingsIntent);
            return true;
        }
		return super.onOptionsItemSelected(item);
	}
	
	@Override
	public void changedState(int state) {
		folderFeedList.changeState(state);
	}
	
	protected void onActivityResult(int requestCode, int resultCode, Intent data) {
		if (resultCode == RESULT_OK) {
			folderFeedList.hasUpdated();
		}
	}

	/**
     * Called after the sync service completely finishes a task.
     */
    @Override
	public void updateAfterSync() {
		folderFeedList.hasUpdated();
		setProgressBarIndeterminateVisibility(false);
        setRefreshEnabled(true);
	}

    /**
     * Called when the sync service has made enough progress to update the UI but not
     * enough to stop the progress indicator.
     */
    @Override
    public void updatePartialSync() {
        // TODO: move 2-step sync to new async lib and remove this method entirely
        // folderFeedList.hasUpdated();
    }
	
	@Override
	public void updateSyncStatus(boolean syncRunning) {
        // TODO: the progress bar is activated manually elsewhere in this activity. this
        //       interface method may be redundant.
		if (syncRunning) {
			setProgressBarIndeterminateVisibility(true);
            setRefreshEnabled(false);
		}
	}

	@Override
	public void setNothingMoreToUpdate() { }

    private void setRefreshEnabled(boolean enabled) {
        if (menu != null) {
            MenuItem item = menu.findItem(R.id.menu_refresh);
            if (item != null) {
                item.setEnabled(enabled);
            }
        }
    }
            

}
