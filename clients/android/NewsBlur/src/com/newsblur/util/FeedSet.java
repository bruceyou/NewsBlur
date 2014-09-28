package com.newsblur.util;

import android.text.TextUtils;
import android.util.Pair;

import java.io.Serializable;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Set;

import com.newsblur.network.APIConstants;

/**
 * A subset of one, several, or all NewsBlur feeds or social feeds.  Used to encapsulate the
 * complexity of the fact that social feeds are special and requesting a river of feeds is not
 * the same as requesting one or more individual feeds.
 */
@SuppressWarnings("serial")
public class FeedSet implements Serializable {

    private static final long serialVersionUID = 0L;

    private Set<String> feeds;
    /** Mapping of social feed IDs to usernames. */
    private Map<String,String> socialFeeds;
    private boolean isAllNormal;
    private boolean isAllSocial;
    private boolean isAllSaved;

    private String folderName;

    /**
     * Construct a new set of feeds. Only one of the arguments may be non-null or true. Specify an empty
     * set to request all of a given type.
     */
    private FeedSet(Set<String> feeds, Map<String,String> socialFeeds, boolean allSaved) {

        if ( booleanCardinality( (feeds != null), (socialFeeds != null), allSaved ) > 1 ) {
            throw new IllegalArgumentException("at most one type of feed may be specified");
        }

        if (feeds != null) {
            if (feeds.size() < 1) {
                isAllNormal = true;
                return;
            } else {
                this.feeds = Collections.unmodifiableSet(feeds);
                return;
            }
        }

        if (socialFeeds != null) {
            if (socialFeeds.size() < 1) {
                isAllSocial = true;
                return;
            } else {
                this.socialFeeds = Collections.unmodifiableMap(socialFeeds);
                return;
            }
        }

        if (allSaved) {
            isAllSaved = true;
            return;
        }

        throw new IllegalArgumentException("no type of feed specified");
    }

    /**
     * Convenience constructor for a single feed.
     */
    public static FeedSet singleFeed(String feedId) {
        Set<String> feedIds = new HashSet<String>(1);
        feedIds.add(feedId);
        return new FeedSet(feedIds, null, false);
    }

    /**
     * Convenience constructor for a single social feed.
     */
    public static FeedSet singleSocialFeed(String userId, String username) {
        Map<String,String> socialFeedIds = new HashMap<String,String>(1);
        socialFeedIds.put(userId, username);
        return new FeedSet(null, socialFeedIds, false);
    }

    /** 
     * Convenience constructor for all (non-social) feeds.
     */
    public static FeedSet allFeeds() {
        return new FeedSet(Collections.EMPTY_SET, null, false);
    }

    /**
     * Convenience constructor for saved stories feed.
     */
    public static FeedSet allSaved() {
        return new FeedSet(null, null, true);
    }

    /** 
     * Convenience constructor for all shared/social feeds.
     */
    public static FeedSet allSocialFeeds() {
        return new FeedSet(null, Collections.EMPTY_MAP, false);
    }

    /** 
     * Convenience constructor for a folder.
     */
    public static FeedSet folder(String folderName, Set<String> feedIds) {
        FeedSet fs = new FeedSet(feedIds, null, false);
        fs.setFolderName(folderName);
        return fs;
    }

    /**
     * Gets a single feed ID iff there is only one or null otherwise.
     */
    public String getSingleFeed() {
        if (feeds != null && folderName == null && feeds.size() == 1) return feeds.iterator().next(); else return null;
    }

    /**
     * Gets a set of feed IDs iff there are multiples or null otherwise.
     */
    public Set<String> getMultipleFeeds() {
        if (feeds != null && (folderName != null || feeds.size() > 1)) return feeds; else return null;
    }

    /**
     * Gets a single social feed ID and username iff there is only one or null otherwise.
     */
    public Map.Entry<String,String> getSingleSocialFeed() {
        if (socialFeeds != null && socialFeeds.size() == 1) return socialFeeds.entrySet().iterator().next(); else return null;
    }

    /**
     * Gets a set of social feed IDs and usernames iff there are multiples or null otherwise.
     */
    public Map<String,String> getMultipleSocialFeeds() {
        if (socialFeeds != null && socialFeeds.size() > 1) return socialFeeds; else return null;
    }

    public boolean isAllNormal() {
        return this.isAllNormal;
    }

    public boolean isAllSocial() {
        return this.isAllSocial;
    }

    public boolean isAllSaved() {
        return this.isAllSaved;
    }

    public void setFolderName(String folderName) {
        this.folderName = folderName;
    }

    public String getFolderName() {
        return this.folderName;
    }

    /**
     * Get a list of feed IDs suitable for passing to mark-read APIs.
     */
    public Set<String> getFeedIds() {
        Set s = new HashSet<String>();
        if (isAllNormal) {
            ; // an empty set represents "all stories"
        } else if (isAllSocial) {
            s.add(APIConstants.VALUE_ALLSOCIAL);
        } else if (feeds != null) {
            s.addAll(feeds);
        } else if ((socialFeeds != null) && (socialFeeds.size() == 1)) {
            s.addAll(socialFeeds.keySet());
        } else {
            throw new UnsupportedOperationException("feed set does not support mark-read ops");
        }
        return s;
    }

    private int booleanCardinality(boolean... args) {
        int card = 0;
        for (boolean b : args) {
            if (b) card++;
        }
        return card;
    }

    @Override
    public boolean equals(Object o) {
        if ( o instanceof FeedSet) {
            FeedSet s = (FeedSet) o;
            if ( (feeds != null) && (s.feeds != null) && TextUtils.equals(folderName, s.folderName) && s.feeds.equals(feeds) ) return true;
            if ( (socialFeeds != null) && (s.socialFeeds != null) && s.socialFeeds.equals(socialFeeds) ) return true;
            if ( isAllNormal && s.isAllNormal ) return true;
            if ( isAllSocial && s.isAllSocial ) return true;
            if ( isAllSaved && s.isAllSaved ) return true;
        }
        return false;
    }

    @Override
    public int hashCode() {
        if (isAllNormal) return 11;
        if (isAllSocial) return 12;
        if (isAllSaved) return 13;

        int result = 17;
        if (feeds != null) result = 31 * result + feeds.hashCode();
        if (socialFeeds != null) result = 31 * result + socialFeeds.hashCode();
        if (folderName != null) result = 31 * result + folderName.hashCode();
        return result;
    }

}
