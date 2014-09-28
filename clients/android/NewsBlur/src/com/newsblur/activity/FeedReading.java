package com.newsblur.activity;

import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.content.CursorLoader;
import android.content.Loader;

import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.FeedReadingAdapter;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Feed;
import com.newsblur.service.NBSyncService;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.StoryOrder;

public class FeedReading extends Reading {

    String feedId;

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        feedId = getIntent().getStringExtra(Reading.EXTRA_FEED);

        Uri classifierUri = FeedProvider.CLASSIFIER_URI.buildUpon().appendPath(feedId).build();
        Cursor feedClassifierCursor = contentResolver.query(classifierUri, null, null, null, null);
        Classifier classifier = Classifier.fromCursor(feedClassifierCursor);

        Uri feedUri = FeedProvider.FEEDS_URI.buildUpon().appendPath(feedId).build();
        Cursor feedCursor = contentResolver.query(feedUri, null, null, null, null);
        Feed feed = Feed.fromCursor(feedCursor);
        feedCursor.close();
        setTitle(feed.title);

        readingAdapter = new FeedReadingAdapter(getFragmentManager(), feed, classifier, defaultFeedView);

        getLoaderManager().initLoader(0, null, this);
    }

    @Override
    protected int getUnreadCount() {
        return dbHelper.getFeedUnreadCount(feedId, currentState);
    }

}
