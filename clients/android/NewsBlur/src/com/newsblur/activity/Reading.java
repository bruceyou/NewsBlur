package com.newsblur.activity;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.ArrayList;
import java.util.List;

import android.content.ContentResolver;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Build;
import android.os.Bundle;
import android.app.DialogFragment;
import android.app.FragmentManager;
import android.app.LoaderManager;
import android.content.Loader;
import android.support.v4.view.ViewPager;
import android.support.v4.view.ViewPager.OnPageChangeListener;
import android.util.Log;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.widget.Button;
import android.widget.ProgressBar;
import android.widget.SeekBar;
import android.widget.SeekBar.OnSeekBarChangeListener;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.domain.Story;
import com.newsblur.fragment.ReadingItemFragment;
import com.newsblur.fragment.ShareDialogFragment;
import com.newsblur.fragment.TextSizeDialogFragment;
import com.newsblur.network.APIManager;
import com.newsblur.util.AppConstants;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.UIUtils;
import com.newsblur.util.ViewUtils;
import com.newsblur.view.NonfocusScrollview.ScrollChangeListener;

public abstract class Reading extends NbActivity implements OnPageChangeListener, OnSeekBarChangeListener, ScrollChangeListener, FeedUtils.ActionCompletionListener, LoaderManager.LoaderCallbacks<Cursor> {

	public static final String EXTRA_FEED = "feed_selected";
	public static final String EXTRA_POSITION = "feed_position";
	public static final String EXTRA_USERID = "user_id";
	public static final String EXTRA_USERNAME = "username";
	public static final String EXTRA_FOLDERNAME = "foldername";
	public static final String EXTRA_FEED_IDS = "feed_ids";
    public static final String EXTRA_DEFAULT_FEED_VIEW = "default_feed_view";
	private static final String TEXT_SIZE = "textsize";
    private static final String BUNDLE_POSITION = "position";
    private static final String BUNDLE_STARTING_UNREAD = "starting_unread";

    private static final int OVERLAY_RANGE_TOP_DP = 40;
    private static final int OVERLAY_RANGE_BOT_DP = 60;

    /** The minimum screen width (in DP) needed to show all the overlay controls. */
    private static final int OVERLAY_MIN_WIDTH_DP = 355;

    /** The longest time (in seconds) the UI will wait for API pages to load while
        searching for the next unread story. */
    private static final long UNREAD_SEARCH_LOAD_WAIT_SECONDS = 30;

    private final Object UNREAD_SEARCH_MUTEX = new Object();
    private CountDownLatch unreadSearchLatch;

	protected int passedPosition;
	protected int currentState;

    protected final Object STORIES_MUTEX = new Object();
	protected Cursor stories;

	protected ViewPager pager;
    protected Button overlayLeft, overlayRight;
    protected ProgressBar overlayProgress, overlayProgressRight, overlayProgressLeft;
    protected Button overlayText, overlaySend;
	protected FragmentManager fragmentManager;
	protected ReadingAdapter readingAdapter;
    protected ContentResolver contentResolver;
    private APIManager apiManager;
    private boolean noMoreApiPages;
    private boolean stopLoading;
    protected volatile boolean requestedPage; // set high iff a syncservice request for stories is already in flight
    private int currentApiPage = 0;

    // unread count for the circular progress overlay. set to nonzero to activate the progress indicator overlay
    protected int startingUnreadCount = 0;

    private float overlayRangeTopPx;
    private float overlayRangeBotPx;

    private List<Story> pageHistory;

    protected DefaultFeedView defaultFeedView;

	@Override
	protected void onCreate(Bundle savedInstanceBundle) {
		super.onCreate(savedInstanceBundle);

		setContentView(R.layout.activity_reading);
        this.overlayLeft = (Button) findViewById(R.id.reading_overlay_left);
        this.overlayRight = (Button) findViewById(R.id.reading_overlay_right);
        this.overlayProgress = (ProgressBar) findViewById(R.id.reading_overlay_progress);
        this.overlayProgressRight = (ProgressBar) findViewById(R.id.reading_overlay_progress_right);
        this.overlayProgressLeft = (ProgressBar) findViewById(R.id.reading_overlay_progress_left);
        this.overlayText = (Button) findViewById(R.id.reading_overlay_text);
        this.overlaySend = (Button) findViewById(R.id.reading_overlay_send);

		fragmentManager = getFragmentManager();

        if ((savedInstanceBundle != null) && savedInstanceBundle.containsKey(BUNDLE_POSITION)) {
            passedPosition = savedInstanceBundle.getInt(BUNDLE_POSITION);
        } else {
            passedPosition = getIntent().getIntExtra(EXTRA_POSITION, 0);
        }

        if ((savedInstanceBundle != null) && savedInstanceBundle.containsKey(BUNDLE_STARTING_UNREAD)) {
            startingUnreadCount = savedInstanceBundle.getInt(BUNDLE_STARTING_UNREAD);
        }

		currentState = getIntent().getIntExtra(ItemsList.EXTRA_STATE, 0);
        defaultFeedView = (DefaultFeedView)getIntent().getSerializableExtra(EXTRA_DEFAULT_FEED_VIEW);
		getActionBar().setDisplayHomeAsUpEnabled(true);

        contentResolver = getContentResolver();

        this.apiManager = new APIManager(this);

        // this value is expensive to compute but doesn't change during a single runtime
        this.overlayRangeTopPx = (float) UIUtils.convertDPsToPixels(this, OVERLAY_RANGE_TOP_DP);
        this.overlayRangeBotPx = (float) UIUtils.convertDPsToPixels(this, OVERLAY_RANGE_BOT_DP);

        this.pageHistory = new ArrayList<Story>();

        // this likes to default to 'on' for some platforms
        enableProgressCircle(overlayProgressLeft, false);
        enableProgressCircle(overlayProgressRight, false);
	}

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        if (pager != null) {
            outState.putInt(BUNDLE_POSITION, pager.getCurrentItem());
        }
        if (startingUnreadCount != 0) {
            outState.putInt(BUNDLE_STARTING_UNREAD, startingUnreadCount);
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        this.stopLoading = false;
        // onCreate() in our subclass should have called createLoader(), but sometimes the callback never makes it.
        // this ensures that at least one callback happens after activity re-create.
        getLoaderManager().restartLoader(0, null, this);
    }

	@Override
	public abstract Loader<Cursor> onCreateLoader(int loaderId, Bundle bundle);

	@Override
	public void onLoaderReset(Loader<Cursor> loader) {
		readingAdapter.swapCursor(null);
	}

	@Override
	public void onLoadFinished(Loader<Cursor> loader, Cursor cursor) {
        synchronized (STORIES_MUTEX) {
            if (cursor != null) {
                readingAdapter.swapCursor(cursor);
                stories = cursor;
            }

            // if this is the first time we've found a cursor, we know the onCreate chain is done
            if (this.pager == null) {

                // don't blow away the value if the value was restored on create
                if (this.startingUnreadCount == 0 ) {
                    this.startingUnreadCount = getUnreadCount();
                }

                // set up the pager after the unread count, so the first mark-read doesn't happen too quickly
                setupPager();
            }

            try {
                readingAdapter.notifyDataSetChanged();
                checkStoryCount(pager.getCurrentItem());
                if (this.unreadSearchLatch != null) {
                    this.unreadSearchLatch.countDown();
                }
                ReadingItemFragment fragment = getReadingFragment();
                if (fragment != null ) {
                    fragment.updateStory(readingAdapter.getStory(pager.getCurrentItem()));
                    fragment.updateSaveButton();

                    updateOverlayText();
                }
            } catch (IllegalStateException ise) {
                // sometimes the pager is already shutting down by the time the callback finishes
                finish();
            }
        }
	}

	private void setupPager() {
		pager = (ViewPager) findViewById(R.id.reading_pager);
		pager.setPageMargin(UIUtils.convertDPsToPixels(getApplicationContext(), 1));
		pager.setPageMarginDrawable(R.drawable.divider_light);
		pager.setOnPageChangeListener(this);
		pager.setAdapter(readingAdapter);

		pager.setCurrentItem(passedPosition, false);
        // setCurrentItem sometimes fails to pass the first page to the callback, so call it manually
        // for the first one.
        this.onPageSelected(passedPosition); 

        this.enableOverlays();
	}

    /**
     * Query the DB for the current unreadcount for this view.
     */
    protected abstract int getUnreadCount();

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);
		MenuInflater inflater = getMenuInflater();
		inflater.inflate(R.menu.reading, menu);
		return true;
	}

    @Override
    public boolean onPrepareOptionsMenu(Menu menu) {
        super.onPrepareOptionsMenu(menu);
        if (readingAdapter == null || pager == null) { return false; }
        Story story = readingAdapter.getStory(pager.getCurrentItem());
        if (story == null ) { return false; }
        menu.findItem(R.id.menu_reading_save).setTitle(story.starred ? R.string.menu_unsave_story : R.string.menu_save_story);
        menu.findItem(R.id.menu_reading_fullscreen).setVisible(Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT);
        return true;
    }

	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
        if (pager == null) return false;
		int currentItem = pager.getCurrentItem();
		Story story = readingAdapter.getStory(currentItem);
        if (story == null) return false;

		if (item.getItemId() == android.R.id.home) {
			finish();
			return true;
		} else if (item.getItemId() == R.id.menu_reading_original) {
            Intent i = new Intent(Intent.ACTION_VIEW);
            i.setData(Uri.parse(story.permalink));
            startActivity(i);
			return true;
		} else if (item.getItemId() == R.id.menu_reading_sharenewsblur) {
            DialogFragment newFragment = ShareDialogFragment.newInstance(getReadingFragment(), story, getReadingFragment().previouslySavedShareText);
            newFragment.show(getFragmentManager(), "dialog");
			return true;
		} else if (item.getItemId() == R.id.menu_shared) {
			FeedUtils.shareStory(story, this);
			return true;
		} else if (item.getItemId() == R.id.menu_textsize) {
			TextSizeDialogFragment textSize = TextSizeDialogFragment.newInstance(PrefsUtils.getTextSize(this));
			textSize.show(getFragmentManager(), TEXT_SIZE);
			return true;
		} else if (item.getItemId() == R.id.menu_reading_save) {
            if (story.starred) {
			    FeedUtils.unsaveStory(story, Reading.this, apiManager, this);
            } else {
                FeedUtils.saveStory(story, Reading.this, apiManager, this);
            }
			return true;
        } else if (item.getItemId() == R.id.menu_reading_markunread) {
            this.markStoryUnread(story);
            return true;
		} else if (item.getItemId() == R.id.menu_reading_fullscreen) {
            ViewUtils.hideSystemUI(getWindow().getDecorView());
            return true;
        } else {
			return super.onOptionsItemSelected(item);
		}
	}

    @Override
    public void actionCompleteCallback(boolean noMoreData) {
		enableMainProgress(false);
        this.requestedPage = false;
        if (this.stopLoading) { return; }

        if (noMoreData) {
		    this.noMoreApiPages = true;
        }
        updateCursor();
    }

    private void updateCursor() {
        getLoaderManager().restartLoader(0, null, this);
    }

    // interface OnPageChangeListener

	@Override
	public void onPageScrollStateChanged(int arg0) {
	}

	@Override
	public void onPageScrolled(int arg0, float arg1, int arg2) {
	}

	@Override
	public void onPageSelected(int position) {
		Story story = readingAdapter.getStory(position);
        if (story != null) {
            synchronized (this.pageHistory) {
                // if the history is just starting out or the last entry in it isn't this page, add this page
                if ((this.pageHistory.size() < 1) || (!story.equals(this.pageHistory.get(this.pageHistory.size()-1)))) {
                    this.pageHistory.add(story);
                }
            }
            markStoryRead(story);
		}
        checkStoryCount(position);

        updateOverlayText();
	}

    // interface ScrollChangeListener

    @Override
    public void scrollChanged(int hPos, int vPos, int currentWidth, int currentHeight) {
        int scrollMax = currentHeight - findViewById(android.R.id.content).getMeasuredHeight();
        int posFromBot = (scrollMax - vPos);

        float newAlpha = 0.0f;
        if ((vPos < this.overlayRangeTopPx) && (posFromBot < this.overlayRangeBotPx)) {
            // if we have a super-tiny scroll window such that we never leave either top or bottom,
            // just leave us at full alpha.
            newAlpha = 1.0f;
        } else if (vPos < this.overlayRangeTopPx) {
            float delta = this.overlayRangeTopPx - ((float) vPos);
            newAlpha = delta / this.overlayRangeTopPx;
        } else if (posFromBot < this.overlayRangeBotPx) {
            float delta = this.overlayRangeBotPx - ((float) posFromBot);
            newAlpha = delta / this.overlayRangeBotPx;
        }
        
        this.setOverlayAlpha(newAlpha);
    }

    private void setOverlayAlpha(float a) {
        // check to see if the device even has room for all the overlays, moving some to overflow if not
        int widthPX = findViewById(android.R.id.content).getMeasuredWidth();
        boolean overflowExtras = false;
        if (widthPX != 0) {
            float widthDP = UIUtils.px2dp(this, widthPX);
            if ( widthDP < OVERLAY_MIN_WIDTH_DP ){
                overflowExtras = true;
            } 
        }

        UIUtils.setViewAlpha(this.overlayLeft, a, true);
        UIUtils.setViewAlpha(this.overlayRight, a, true);
        UIUtils.setViewAlpha(this.overlayProgress, a, true);
        UIUtils.setViewAlpha(this.overlayText, a, true);
        UIUtils.setViewAlpha(this.overlaySend, a, !overflowExtras);
    }

    /**
     * Check and correct the display status of the overlays.  Call this any time
     * an event happens that might change our list position.
     */
    private void enableOverlays() {
        this.setOverlayAlpha(1.0f);

        this.overlayLeft.setEnabled(this.getLastReadPosition(false) != -1);
        this.overlayRight.setText((getUnreadCount() > 0) ? R.string.overlay_next : R.string.overlay_done);
        this.overlayRight.setBackgroundResource((getUnreadCount() > 0) ? R.drawable.selector_overlay_bg_right : R.drawable.selector_overlay_bg_right_done);

        if (this.startingUnreadCount == 0 ) {
            // sessions with no unreads just show a full progress bar
            this.overlayProgress.setMax(1);
            this.overlayProgress.setProgress(1);
        } else {
            int unreadProgress = this.startingUnreadCount - getUnreadCount();
            this.overlayProgress.setMax(this.startingUnreadCount);
            this.overlayProgress.setProgress(unreadProgress);
        }
        this.overlayProgress.invalidate();

        invalidateOptionsMenu();
    }

    public void onWindowFocusChanged(boolean hasFocus) {
        // this callback is a good API-level-independent way to tell when the root view size/layout changes
        super.onWindowFocusChanged(hasFocus);
        enableOverlays();

        // Ensure that we come out of immersive view if the activity no longer has focus
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT && !hasFocus) {
            getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_VISIBLE);
        }
    }

	/**
     * While navigating the story list and at the specified position, see if it is possible
     * and desirable to start loading more stories in the background.  Note that if a load
     * is triggered, this method will be called again by the callback to ensure another
     * load is not needed and all latches are tripped.
     */
    private void checkStoryCount(int position) {
        if (AppConstants.VERBOSE_LOG) {
            Log.d(this.getClass().getName(), String.format("story %d of %d selected, noMore pages: %b, requestedPg: %b, stopLoad: %b", position, stories.getCount(), noMoreApiPages, requestedPage, stopLoading));
        }
        // if the pager is at or near the number of stories loaded, check for more unless we know we are at the end of the list
		if (((position + AppConstants.READING_STORY_PRELOAD) >= stories.getCount()) && !noMoreApiPages && !requestedPage && !stopLoading) {
			currentApiPage += 1;
			requestedPage = true;
            enableMainProgress(true);
			triggerRefresh(currentApiPage);
		}
        
        if (noMoreApiPages || stopLoading) {
        // if we terminated because we are well and truly done, break any search loops and stop progress indication
            enableMainProgress(false);
            if (this.unreadSearchLatch != null) {
                this.unreadSearchLatch.countDown();
            }
        }
	}

	protected void enableMainProgress(boolean enabled) {
        enableProgressCircle(overlayProgressRight, enabled);
	}

    public void enableLeftProgressCircle(boolean enabled) {
        enableProgressCircle(overlayProgressLeft, enabled);
    }

    private void enableProgressCircle(final ProgressBar view, final boolean enabled) {
        runOnUiThread(new Runnable() {
            public void run() {
                if (enabled) {
                    view.setProgress(0);
                    view.setVisibility(View.VISIBLE);
                } else {
                    view.setProgress(100);
                    view.setVisibility(View.GONE);
                }
            }
        });
	}
        
	protected abstract void triggerRefresh(int page);

    @Override
    protected void onPause() {
        this.stopLoading = true;
        if (this.unreadSearchLatch != null) {
            this.unreadSearchLatch.countDown();
        }
        super.onPause();
    }

    private void markStoryRead(Story story) {
        synchronized (STORIES_MUTEX) {
            FeedUtils.markStoryAsRead(story, this);
            updateCursor();
        }
        enableOverlays();
    }

    private void markStoryUnread(Story story) {
        synchronized (STORIES_MUTEX) {
            FeedUtils.markStoryUnread(story, this);
            updateCursor();
        }
        enableOverlays();
    }

    // NB: this callback is for the text size slider
	@Override
	public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
        float size = AppConstants.READING_FONT_SIZE[progress];
	    PrefsUtils.setTextSize(this, size);
		Intent data = new Intent(ReadingItemFragment.TEXT_SIZE_CHANGED);
		data.putExtra(ReadingItemFragment.TEXT_SIZE_VALUE, size); 
		sendBroadcast(data);
	}

	@Override
	public void onStartTrackingTouch(SeekBar seekBar) {
	}

	@Override
	public void onStopTrackingTouch(SeekBar seekBar) {
	}

    /**
     * Click handler for the righthand overlay nav button.
     */
    public void overlayRight(View v) {
        if (getUnreadCount() <= 0) {
            // if there are no unread stories, go back to the feed list
            Intent i = new Intent(this, Main.class);
            i.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);
            startActivity(i);
        } else {
            // if there are unreads, go to the next one
            new AsyncTask<Void, Void, Void>() {
                @Override
                protected Void doInBackground(Void... params) {
                    nextUnread();
                    return null;
                }
            }.execute();
        }
    }

    /**
     * Search our set of stories for the next unread one.  This requires some heavy
     * cooperation with the way stories are automatically loaded in the background
     * as we walk through the list.
     */
    private void nextUnread() {
        synchronized (UNREAD_SEARCH_MUTEX) {
            int candidate = 0;
            boolean unreadFound = false;
            boolean error = false;
            unreadSearch:while (!unreadFound) {
                Story story = readingAdapter.getStory(candidate);

                if (this.stopLoading) {
                    // this activity was ended before we finished. just stop.
                    break unreadSearch;
                } 

                if (story == null) {
                    if (this.noMoreApiPages) {
                        // this is odd. if there were no unreads, how was the button even enabled?
                        Log.w(this.getClass().getName(), "Ran out of stories while looking for unreads.");
                        break unreadSearch;
                    } 
                } else {
                    if ((candidate == pager.getCurrentItem()) || (story.read) ) {
                        candidate++;
                        continue unreadSearch;
                    } else {
                        unreadFound = true;
                        break unreadSearch;
                    }
                }

                // if we didn't find a story trigger a check to see if there are any more to search before proceeding
                this.unreadSearchLatch = new CountDownLatch(1);
                this.checkStoryCount(candidate+1);
                try {
                    boolean unlatched = this.unreadSearchLatch.await(UNREAD_SEARCH_LOAD_WAIT_SECONDS, TimeUnit.SECONDS);
                    if (unlatched) {
                        continue unreadSearch;
                    } else {
                        Log.e(this.getClass().getName(), "Timed out waiting for next API page while looking for unreads.");
                        error = true;
                        break unreadSearch;
                    }
                } catch (InterruptedException ie) {
                    Log.e(this.getClass().getName(), "Interrupted waiting for next API page while looking for unreads.");
                    error = true;
                    break unreadSearch;
                }

            }
            if (error) {
                runOnUiThread(new Runnable() {
                    public void run() {
                        Toast.makeText(Reading.this, R.string.toast_unread_search_error, Toast.LENGTH_LONG).show();
                    }
                });
                return;
            }
            if (unreadFound) {
                final int page = candidate;
                runOnUiThread(new Runnable() {
                    public void run() {
                        pager.setCurrentItem(page, true);
                    }
                });
                return;
            }
            Log.w(this.getClass().getName(), "got neither errors nor unreads nor null response looking for unreads");
        }
    }

    /**
     * Click handler for the lefthand overlay nav button.
     */
    public void overlayLeft(View v) {
        int targetPosition = this.getLastReadPosition(true);
        if (targetPosition != -1) {
            pager.setCurrentItem(targetPosition, true);
        } else {
            Log.e(this.getClass().getName(), "reading history contained item not found in cursor.");
        }
    }

    /**
     * Get the pager position of the last story read during this activity or -1 if there is nothing
     * in the history.
     *
     * @param trimHistory optionally trim the history of the currently displayed page iff the
     *        back button has been pressed.
     */
    private int getLastReadPosition(boolean trimHistory) {
        synchronized (this.pageHistory) {
            // the last item is always the currently shown page, do not count it
            if (this.pageHistory.size() < 2) {
                return -1;
            }
            Story targetStory = this.pageHistory.get(this.pageHistory.size()-2);
            int targetPosition = this.readingAdapter.getPosition(targetStory);
            if (trimHistory && (targetPosition != -1)) {
                this.pageHistory.remove(this.pageHistory.size()-1);
            }
            return targetPosition;
        }
    }

    /**
     * Click handler for the progress indicator on the righthand overlay nav button.
     */
    public void overlayCount(View v) {
        String unreadText = getString((getUnreadCount() == 1) ? R.string.overlay_count_toast_1 : R.string.overlay_count_toast_N);
        Toast.makeText(this, String.format(unreadText, getUnreadCount()), Toast.LENGTH_SHORT).show();
    }

    public void overlaySend(View v) {
		Story story = readingAdapter.getStory(pager.getCurrentItem());
        FeedUtils.shareStory(story, this);
    }

    public void overlayText(View v) {
        ReadingItemFragment item = getReadingFragment();
        if (item == null) return;
        item.switchSelectedFeedView();
        updateOverlayText();
    }

    private void updateOverlayText() {
        ReadingItemFragment item = getReadingFragment();
        if ((item == null) || (this.overlayText == null)) return;
        if (item.getSelectedFeedView() == DefaultFeedView.STORY) {
            this.overlayText.setBackgroundResource(R.drawable.selector_overlay_bg_text);
            this.overlayText.setText(R.string.overlay_text);
        } else {
            this.overlayText.setBackgroundResource(R.drawable.selector_overlay_bg_story);
            this.overlayText.setText(R.string.overlay_story);
        }
    }

    private ReadingItemFragment getReadingFragment() {
        if (readingAdapter == null || pager == null) { return null; }
        Object o = readingAdapter.instantiateItem(pager, pager.getCurrentItem());
        if (o instanceof ReadingItemFragment) {
            return (ReadingItemFragment) o;
        } else {
            return null;
        }
    }
}
