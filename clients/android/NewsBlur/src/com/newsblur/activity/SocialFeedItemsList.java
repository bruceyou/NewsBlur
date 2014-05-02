package com.newsblur.activity;

import android.content.Intent;
import android.os.Bundle;
import android.app.FragmentTransaction;
import android.view.Menu;
import android.view.MenuInflater;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.fragment.FeedItemListFragment;
import com.newsblur.fragment.SocialFeedItemListFragment;
import com.newsblur.network.APIManager;
import com.newsblur.network.MarkSocialFeedAsReadTask;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StoryOrder;

public class SocialFeedItemsList extends ItemsList {

	private String userIcon, userId, username, title;
	private APIManager apiManager;

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

		apiManager = new APIManager(this);
		
		username = getIntent().getStringExtra(EXTRA_BLURBLOG_USERNAME);
		userIcon = getIntent().getStringExtra(EXTRA_BLURBLOG_USER_ICON );
		userId = getIntent().getStringExtra(EXTRA_BLURBLOG_USERID);
		title = getIntent().getStringExtra(EXTRA_BLURBLOG_TITLE);
				
		setTitle(title);
		
		if (itemListFragment == null) {
			itemListFragment = SocialFeedItemListFragment.newInstance(userId, username, currentState, getStoryOrder(), getDefaultFeedView());
			itemListFragment.setRetainInstance(true);
			FragmentTransaction listTransaction = fragmentManager.beginTransaction();
			listTransaction.add(R.id.activity_itemlist_container, itemListFragment, SocialFeedItemListFragment.class.getName());
			listTransaction.commit();
		}
	}
	

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);
		MenuInflater inflater = getMenuInflater();
		inflater.inflate(R.menu.itemslist, menu);
		return true;
	}
	
	@Override
	public void triggerRefresh(int page) {
		if (!stopLoading) {
			setProgressBarIndeterminateVisibility(true);
            FeedUtils.updateSocialFeed(this, this, userId, username, page, getStoryOrder(), PrefsUtils.getReadFilterForFeed(this, userId));
		}
	}

	@Override
	public void markItemListAsRead() {
		new MarkSocialFeedAsReadTask(apiManager, getContentResolver()){
			@Override
			protected void onPostExecute(Boolean result) {
				if (result.booleanValue()) {
					setResult(RESULT_OK);
					Toast.makeText(SocialFeedItemsList.this, R.string.toast_marked_socialfeed_as_read, Toast.LENGTH_SHORT).show();
					finish();
				} else {
					Toast.makeText(SocialFeedItemsList.this, R.string.toast_error_marking_feed_as_read, Toast.LENGTH_LONG).show();
				}
			}
		}.execute(userId);
	}

    @Override
    protected StoryOrder getStoryOrder() {
        return PrefsUtils.getStoryOrderForFeed(this, userId);
    }

    @Override
    public void updateStoryOrderPreference(StoryOrder newValue) {
        PrefsUtils.setStoryOrderForFeed(this, userId, newValue);
    }
    
    @Override
    protected void updateReadFilterPreference(ReadFilter newValue) {
        PrefsUtils.setReadFilterForFeed(this, userId, newValue);
    }
    
    @Override
    protected ReadFilter getReadFilter() {
        return PrefsUtils.getReadFilterForFeed(this, userId);
    }

    @Override
    protected DefaultFeedView getDefaultFeedView() {
        return PrefsUtils.getDefaultFeedViewForFeed(this, userId);
    }

    @Override
    public void defaultFeedViewChanged(DefaultFeedView value) {
        PrefsUtils.setDefaultFeedViewForFeed(this, userId, value);
        if (itemListFragment != null) {
            itemListFragment.setDefaultFeedView(value);
        }
    }
}
