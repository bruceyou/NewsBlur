package com.newsblur.fragment;

import android.app.LoaderManager;
import android.content.ContentResolver;
import android.content.CursorLoader;
import android.content.Intent;
import android.content.Loader;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemClickListener;
import android.widget.CursorAdapter;
import android.widget.ListView;
import android.widget.SimpleCursorAdapter;

import com.newsblur.R;
import com.newsblur.activity.ItemsList;
import com.newsblur.activity.Reading;
import com.newsblur.activity.SocialFeedReading;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.MultipleFeedItemsAdapter;
import com.newsblur.domain.SocialFeed;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.StoryOrder;
import com.newsblur.view.SocialItemViewBinder;

public class SocialFeedItemListFragment extends ItemListFragment implements LoaderManager.LoaderCallbacks<Cursor>, OnItemClickListener {

	private ContentResolver contentResolver;
	private String userId, username;
	private Uri storiesUri;
	private SocialFeed socialFeed;
    private int currentState;
	
	public static int ITEMLIST_LOADER = 0x01;
	private Uri socialFeedUri;
	private String[] groupFroms;
	private int[] groupTos;
	private ListView itemList;
    private StoryOrder storyOrder;

    @Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		currentState = getArguments().getInt("currentState");
        userId = getArguments().getString("userId");
        username = getArguments().getString("username");
        storyOrder = (StoryOrder)getArguments().getSerializable("storyOrder");
        defaultFeedView = (DefaultFeedView)getArguments().getSerializable("defaultFeedView");
		contentResolver = getActivity().getContentResolver();
		storiesUri = FeedProvider.SOCIALFEED_STORIES_URI.buildUpon().appendPath(userId).build();
		
		setupSocialFeed();

		Uri uri = FeedProvider.SOCIALFEED_STORIES_URI.buildUpon().appendPath(userId).build();
		Cursor cursor = getActivity().getContentResolver().query(uri, null, DatabaseConstants.getStorySelectionFromState(currentState), null, DatabaseConstants.getStorySharedSortOrder(storyOrder));
		
		groupFroms = new String[] { DatabaseConstants.STORY_TITLE, DatabaseConstants.FEED_FAVICON_URL, DatabaseConstants.FEED_TITLE, DatabaseConstants.STORY_SHORT_CONTENT, DatabaseConstants.STORY_TIMESTAMP, DatabaseConstants.STORY_AUTHORS, DatabaseConstants.STORY_INTELLIGENCE_AUTHORS};
		groupTos = new int[] { R.id.row_item_title, R.id.row_item_feedicon, R.id.row_item_feedtitle, R.id.row_item_content, R.id.row_item_date, R.id.row_item_author, R.id.row_item_sidebar};

        adapter = new MultipleFeedItemsAdapter(getActivity(), R.layout.row_socialitem, cursor, groupFroms, groupTos, CursorAdapter.FLAG_REGISTER_CONTENT_OBSERVER);
        adapter.setViewBinder(new SocialItemViewBinder(getActivity()));

		getLoaderManager().initLoader(ITEMLIST_LOADER , null, this);
		
	}

	private void setupSocialFeed() {
		socialFeedUri = FeedProvider.SOCIAL_FEEDS_URI.buildUpon().appendPath(userId).build();
		socialFeed = SocialFeed.fromCursor(contentResolver.query(socialFeedUri, null, null, null, null));
	}
	
	public static SocialFeedItemListFragment newInstance(final String userId, final String username, final int currentState, final StoryOrder storyOrder, final DefaultFeedView defaultFeedView) {
	    SocialFeedItemListFragment fragment = new SocialFeedItemListFragment();
		Bundle args = new Bundle();
        args.putInt("currentState", currentState);
        args.putString("userId", userId);
        args.putString("username", username);
        args.putSerializable("storyOrder", storyOrder);
        args.putSerializable("defaultFeedView", defaultFeedView);
        fragment.setArguments(args);
        return fragment;
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		View v = inflater.inflate(R.layout.fragment_itemlist, null);
		itemList = (ListView) v.findViewById(R.id.itemlistfragment_list);
        setupBezelSwipeDetector(itemList);
		itemList.setEmptyView(v.findViewById(R.id.empty_view));
		
		itemList.setOnScrollListener(this);
		itemList.setAdapter(adapter);
		itemList.setOnItemClickListener(this);
		
		return v;
	}

	@Override
	public Loader<Cursor> onCreateLoader(int loaderId, Bundle bundle) {
		Uri uri = FeedProvider.SOCIALFEED_STORIES_URI.buildUpon().appendPath(userId).build();
		CursorLoader cursorLoader = new CursorLoader(getActivity(), uri, null, DatabaseConstants.getStorySelectionFromState(currentState), null, DatabaseConstants.getStorySharedSortOrder(storyOrder));
	    return cursorLoader;
	}

	public void hasUpdated() {
		setupSocialFeed();
		requestedPage = false;
        if (isAdded()) {
		    getLoaderManager().restartLoader(ITEMLIST_LOADER , null, this);
        }
	}

	@Override
	public void onLoaderReset(Loader<Cursor> loader) {
		adapter.notifyDataSetInvalidated();
	}
	
	@Override
	public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
        if (getActivity().isFinishing()) return;
		Intent i = new Intent(getActivity(), SocialFeedReading.class);
		i.putExtra(Reading.EXTRA_USERID, userId);
		i.putExtra(Reading.EXTRA_USERNAME, username);
		i.putExtra(Reading.EXTRA_POSITION, position);
		i.putExtra(ItemsList.EXTRA_STATE, currentState);
        i.putExtra(Reading.EXTRA_DEFAULT_FEED_VIEW, defaultFeedView);
		startActivity(i);
	}

	public void changeState(int state) {
		currentState = state;
        hasUpdated();
	}

	@Override
    public void setStoryOrder(StoryOrder storyOrder) {
        this.storyOrder = storyOrder;
    }
}
