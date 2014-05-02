package com.newsblur.activity;

import java.util.ArrayList;
import java.util.List;

import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Intent;
import android.database.Cursor;
import android.os.AsyncTask;
import android.os.Bundle;
import android.app.FragmentTransaction;
import android.view.Menu;
import android.view.MenuInflater;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.fragment.AllStoriesItemListFragment;
import com.newsblur.fragment.FeedItemListFragment;
import com.newsblur.fragment.MarkAllReadDialogFragment;
import com.newsblur.fragment.MarkAllReadDialogFragment.MarkAllReadDialogListener;
import com.newsblur.network.APIManager;
import com.newsblur.util.AppConstants;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StoryOrder;

public class AllStoriesItemsList extends ItemsList implements MarkAllReadDialogListener {

	private APIManager apiManager;
	private ContentResolver resolver;
	private ArrayList<String> feedIds;

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

		setTitle(getResources().getString(R.string.all_stories));

		apiManager = new APIManager(this);
		resolver = getContentResolver();

        if (bundle != null) {
            feedIds = bundle.getStringArrayList(BUNDLE_FEED_IDS);
        }

        if (feedIds == null) {
            feedIds = new ArrayList<String>(); // default to a wildcard search

            // if we're in Focus mode, only query for feeds with a nonzero focus count
            if (this.currentState == AppConstants.STATE_BEST) {
                Cursor cursor = resolver.query(FeedProvider.FEEDS_URI, null, DatabaseConstants.FEED_FILTER_FOCUS, null, null);
                while (cursor.moveToNext() && (feedIds.size() <= AppConstants.MAX_FEED_LIST_SIZE)) {
                    feedIds.add(cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_ID)));
                }
                cursor.close();
            }
        }

		itemListFragment = (AllStoriesItemListFragment) fragmentManager.findFragmentByTag(AllStoriesItemListFragment.class.getName());
		if (itemListFragment == null) {
			itemListFragment = AllStoriesItemListFragment.newInstance(feedIds, currentState, getStoryOrder(), getDefaultFeedView());
			itemListFragment.setRetainInstance(true);
			FragmentTransaction listTransaction = fragmentManager.beginTransaction();
			listTransaction.add(R.id.activity_itemlist_container, itemListFragment, AllStoriesItemListFragment.class.getName());
			listTransaction.commit();
		}
	}

	@Override
	public void triggerRefresh(int page) {
		if (!stopLoading) {
			setProgressBarIndeterminateVisibility(true);

            String[] feedIdArray = new String[feedIds.size()];
            feedIds.toArray(feedIdArray);
            FeedUtils.updateFeeds(this, this, feedIdArray, page, getStoryOrder(), PrefsUtils.getReadFilterForFolder(this, PrefConstants.ALL_STORIES_FOLDER_NAME));
		}
	}

	@Override
	public void markItemListAsRead() {
	    MarkAllReadDialogFragment dialog = MarkAllReadDialogFragment.newInstance(getResources().getString(R.string.all_stories));
        dialog.show(fragmentManager, "dialog");
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);
		MenuInflater inflater = getMenuInflater();
		inflater.inflate(R.menu.allstories_itemslist, menu);
		return true;
	}

    @Override
    protected StoryOrder getStoryOrder() {
        return PrefsUtils.getStoryOrderForFolder(this, PrefConstants.ALL_STORIES_FOLDER_NAME);
    }

    @Override
    public void updateStoryOrderPreference(StoryOrder newValue) {
        PrefsUtils.setStoryOrderForFolder(this, PrefConstants.ALL_STORIES_FOLDER_NAME, newValue);
    }
    
    @Override
    protected void updateReadFilterPreference(ReadFilter newValue) {
        PrefsUtils.setReadFilterForFolder(this, PrefConstants.ALL_STORIES_FOLDER_NAME, newValue);
    }
    
    @Override
    protected ReadFilter getReadFilter() {
        return PrefsUtils.getReadFilterForFolder(this, PrefConstants.ALL_STORIES_FOLDER_NAME);
    }

    @Override
    protected DefaultFeedView getDefaultFeedView() {
        return PrefsUtils.getDefaultFeedViewForFolder(this, PrefConstants.ALL_STORIES_FOLDER_NAME);
    }

    @Override
    public void defaultFeedViewChanged(DefaultFeedView value) {
        PrefsUtils.setDefaultFeedViewForFolder(this, PrefConstants.ALL_STORIES_FOLDER_NAME, value);
        if (itemListFragment != null) {
            itemListFragment.setDefaultFeedView(value);
        }
    }

    @Override
    public void onMarkAllRead() {
        new AsyncTask<Void, Void, Boolean>() {
            @Override
            protected Boolean doInBackground(Void... arg) {
                return apiManager.markAllAsRead();
            }
            
            @Override
            protected void onPostExecute(Boolean result) {
                if (result) {
                    // mark all feed IDs as read
                    ContentValues values = new ContentValues();
                    values.put(DatabaseConstants.FEED_NEGATIVE_COUNT, 0);
                    values.put(DatabaseConstants.FEED_NEUTRAL_COUNT, 0);
                    values.put(DatabaseConstants.FEED_POSITIVE_COUNT, 0);
                    resolver.update(FeedProvider.FEEDS_URI, values, null, null);
                    setResult(RESULT_OK); 
                    Toast.makeText(AllStoriesItemsList.this, R.string.toast_marked_all_stories_as_read, Toast.LENGTH_SHORT).show();
                    finish();
                } else {
                    Toast.makeText(AllStoriesItemsList.this, R.string.toast_error_marking_feed_as_read, Toast.LENGTH_SHORT).show();
                }
            };
        }.execute();
    }

    @Override
    public void onCancel() {
        // do nothing
    }

    @Override
    protected void onSaveInstanceState(Bundle bundle) {
        if (this.feedIds != null) {
            bundle.putStringArrayList(BUNDLE_FEED_IDS, this.feedIds);
        }
        super.onSaveInstanceState(bundle);
    }
}
