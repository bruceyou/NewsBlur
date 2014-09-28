package com.newsblur.fragment;

import java.util.ArrayList;
import java.util.List;

import android.app.Activity;
import android.app.Fragment;
import android.app.LoaderManager;
import android.content.Intent;
import android.content.Loader;
import android.database.Cursor;
import android.os.Bundle;
import android.util.Log;
import android.view.ContextMenu;
import android.view.GestureDetector;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.MotionEvent;
import android.view.View;
import android.view.View.OnTouchListener;
import android.view.ContextMenu.ContextMenuInfo;
import android.view.View.OnCreateContextMenuListener;
import android.widget.AbsListView;
import android.widget.AbsListView.OnScrollListener;
import android.widget.AdapterView;
import android.widget.ListView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.activity.ItemsList;
import com.newsblur.database.StoryItemsAdapter;
import com.newsblur.domain.Story;
import com.newsblur.network.APIManager;
import com.newsblur.util.AppConstants;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StoryOrder;

public abstract class ItemListFragment extends NbFragment implements OnScrollListener, OnCreateContextMenuListener, LoaderManager.LoaderCallbacks<Cursor> {

	public static int ITEMLIST_LOADER = 0x01;

	protected StoryItemsAdapter adapter;
    protected DefaultFeedView defaultFeedView;
	protected int currentState;
    private int lastRequestedStoryCount = 0;
    private boolean isLoading = true;

    @Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
    }

    /**
     * Indicate that the DB was cleared.
     */
    public void resetEmptyState() {
        setLoading(true);
        lastRequestedStoryCount = 0;
    }

    public void setLoading(boolean loading) {
        isLoading = loading;
    }

    private void updateLoadingIndicator() {
        View v = this.getView();
        if (v == null) return; // we might have beat construction?

        ListView itemList = (ListView) v.findViewById(R.id.itemlistfragment_list);
        if (itemList == null) {
            Log.w(this.getClass().getName(), "ItemListFragment does not have the expected ListView.");
            return;
        }
        TextView emptyView = (TextView) itemList.getEmptyView();

        if (isLoading) {
            emptyView.setText(R.string.empty_list_view_loading);
        } else {
            emptyView.setText(R.string.empty_list_view_no_stories);
        }
    }

    public void scrollToTop() {
        View v = this.getView();
        if (v == null) return; // we might have beat construction?

        ListView itemList = (ListView) v.findViewById(R.id.itemlistfragment_list);
        if (itemList == null) {
            Log.w(this.getClass().getName(), "ItemListFragment does not have the expected ListView.");
            return;
        }

        itemList.setSelection(0);
    }

	@Override
	public synchronized void onScroll(AbsListView view, int firstVisible, int visibleCount, int totalCount) {
        // load an extra page or two worth of stories past the viewport
        int desiredStoryCount = firstVisible + (visibleCount*2);

        // this method tends to get called repeatedly. don't request repeats
        if (desiredStoryCount <= lastRequestedStoryCount) {
            return;
        }
        lastRequestedStoryCount = desiredStoryCount;

        triggerRefresh(desiredStoryCount);
	}

	@Override
	public void onScrollStateChanged(AbsListView view, int scrollState) { }

	public void changeState(int state) {
		currentState = state;
		hasUpdated();
	}

	private void triggerRefresh(int desiredStories) {
        ((ItemsList) getActivity()).triggerRefresh(desiredStories);
    }

    protected FeedSet getFeedSet() {
        return ((ItemsList) getActivity()).getFeedSet();
    }

	public void hasUpdated() {
        if (isAdded()) {
		    getLoaderManager().restartLoader(ITEMLIST_LOADER , null, this);
        }
	}

	@Override
	public Loader<Cursor> onCreateLoader(int arg0, Bundle arg1) {
		return dbHelper.getStoriesLoader(getFeedSet(), currentState);
	}

    @Override
	public void onLoadFinished(Loader<Cursor> loader, Cursor cursor) {
		if (cursor != null) {
            if (cursor.getCount() == 0) {
                triggerRefresh(1);
            }
			adapter.swapCursor(cursor);
		}
        updateLoadingIndicator();
	}

	@Override
	public void onLoaderReset(Loader<Cursor> loader) {
		adapter.notifyDataSetInvalidated();
	}

    public void setDefaultFeedView(DefaultFeedView value) {
        this.defaultFeedView = value;
    }

    @Override
    public void onCreateContextMenu(ContextMenu menu, View v, ContextMenuInfo menuInfo) {
        MenuInflater inflater = getActivity().getMenuInflater();
        inflater.inflate(R.menu.context_story, menu);

        Story story = adapter.getStory(((AdapterView.AdapterContextMenuInfo) (menuInfo)).position);
        if (story.read) {
            menu.removeItem(R.id.menu_mark_story_as_read);
        } else {
            menu.removeItem(R.id.menu_mark_story_as_unread);
        }

        if (story.starred) {
            menu.removeItem(R.id.menu_save_story);
        } else {
            menu.removeItem(R.id.menu_unsave_story);
        }
    }
    
    @Override
    public boolean onContextItemSelected(MenuItem item) {
        AdapterView.AdapterContextMenuInfo menuInfo = (AdapterView.AdapterContextMenuInfo)item.getMenuInfo();
        Story story = adapter.getStory(menuInfo.position);
        Activity activity = getActivity();

        switch (item.getItemId()) {
        case R.id.menu_mark_story_as_read:
            FeedUtils.markStoryAsRead(story, activity);
            hasUpdated();
            return true;

        case R.id.menu_mark_story_as_unread:
            FeedUtils.markStoryUnread(story, activity);
            hasUpdated();
            return true;

        case R.id.menu_mark_previous_stories_as_read:
            FeedUtils.markFeedsRead(getFeedSet(), story.timestamp, null, activity);
            hasUpdated();
            return true;

        case R.id.menu_shared:
            FeedUtils.shareStory(story, activity);
            return true;

        case R.id.menu_save_story:
            FeedUtils.saveStory(story, activity, new APIManager(activity));
            return true;

        case R.id.menu_unsave_story:
            FeedUtils.unsaveStory(story, activity, new APIManager(activity));
            return true;

        default:
            return super.onContextItemSelected(item);
        }
    }

    protected void setupBezelSwipeDetector(View v) {
        final GestureDetector gestureDetector = new GestureDetector(getActivity(), new BezelSwipeDetector());
        v.setOnTouchListener(new OnTouchListener() {
            public boolean onTouch(View v, MotionEvent event) {
                return gestureDetector.onTouchEvent(event);
            }
        });
    }

    /**
     * A gesture detector that captures bezel swipes and finishes the activity,
     * to simulate a 'back' gesture.
     *
     * NB: pretty much all Views still try to process on-tap events despite
     *     returning true, so be sure to check isFinishing() on all other
     *     tap handlers.
     */
    class BezelSwipeDetector extends GestureDetector.SimpleOnGestureListener {
        @Override
        public boolean onScroll(MotionEvent e1, MotionEvent e2, float distanceX, float distanceY) {
            if((e1.getX() < 75f) &&                  // the gesture should start from the left bezel and
               ((e2.getX()-e1.getX()) > 90f) &&      // move horizontally to the right and
               (Math.abs(e1.getY()-e2.getY()) < 40f) // have minimal vertical travel, so we don't capture scrolling gestures
               ) {
                ItemListFragment.this.getActivity().finish();
                return true;
            }
            return false;
        }
    }
}
