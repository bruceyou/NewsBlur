NEWSBLUR.ReaderFeedchooser = function(options) {
    options = options || {};
    var defaults = {
        'width': options.premium_only || options.chooser_only ? 460 : 900,
        'premium_only': false,
        'chooser_only': false,
        'onOpen': _.bind(function() {
            this.resize_modal();
        }, this),
        'onClose': _.bind(function() {
            if (!this.flags['has_saved'] && !this.model.flags['has_chosen_feeds']) {
                NEWSBLUR.reader.show_feed_chooser_button();
            }
            dialog.data.hide().empty().remove();
            dialog.container.hide().empty().remove();
            dialog.overlay.fadeOut(200, function() {
                dialog.overlay.empty().remove();
                $.modal.close(callback);
            });
            $('.NB-modal-holder').empty().remove();
        }, this)
    };

    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.runner();
};

NEWSBLUR.ReaderFeedchooser.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderFeedchooser.prototype.constructor = NEWSBLUR.ReaderFeedchooser;

_.extend(NEWSBLUR.ReaderFeedchooser.prototype, {
    
    runner: function() {
        this.start = new Date();
        this.MAX_FEEDS = 64;
        this.approve_list = [];
        this.make_modal();
        this.make_paypal_button();

        if (!this.options.premium_only) {
            this.find_feeds_in_feed_list();
            this.initial_load_feeds();
        }
        this.choose_dollar_amount(2);
        
        this.flags = {
            'has_saved': false
        };
        this.open_modal();
        
        this.$modal.bind('mousedown', $.rescope(this.handle_mousedown, this));
        this.$modal.bind('change', $.rescope(this.handle_change, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-feedchooser NB-modal ' + (this.options.premium_only ? "NB-feedchooser-premium" : this.options.chooser_only ? "NB-feedchooser-chooser-only" : "NB-feedchooser-standard") }, [
            // $.make('h2', { className: 'NB-modal-title' }, 'Choose Your '+this.MAX_FEEDS),
            (!this.options.chooser_only && $.make('div', { className: 'NB-feedchooser-type NB-right' }, [
              (!this.options.premium_only && $.make('div', { className: 'NB-feedchooser-porpoise' }, 'OR')),
              (NEWSBLUR.Globals.is_premium && $.make('div', { className: 'NB-feedchooser-info'}, [
                  $.make('div', { className: 'NB-feedchooser-info-type' }, [
                        $.make('span', { className: 'NB-feedchooser-subtitle-type-prefix' }, 'Thank you'),
                        ' for going premium!'
                  ]),
                  $.make('h2', { className: 'NB-modal-subtitle' }, [
                      'Your premium account will renew on:',
                      $.make('br'),
                      $.make('b', { style: 'display: block; margin: 8px 0' }, [
                          $.make('span', { className: 'NB-raquo' }, '&raquo;'),
                          ' ',
                          NEWSBLUR.Globals.premium_expire && NEWSBLUR.utils.format_date(NEWSBLUR.Globals.premium_expire)
                      ]),
                      'You can change your payment method and card details. ',
                      (NEWSBLUR.Globals.premium_expire < new Date) ? 
                      'This will charge your card immediately.' :
                      'You won\'t be charged until this date.'
                  ])
              ])),
              (!NEWSBLUR.Globals.is_premium && $.make('div', { className: 'NB-feedchooser-info'}, [
                  $.make('div', { className: 'NB-feedchooser-info-type' }, [
                    $.make('span', { className: 'NB-feedchooser-subtitle-type-prefix' }, '付费'),
                    ' 高级帐户'
                  ])
              ])),
              $.make('ul', { className: 'NB-feedchooser-premium-bullets' }, [
                $.make('li', { className: 'NB-1' }, [
                  $.make('div', { className: 'NB-feedchooser-premium-bullet-image' }),
                  '付费之后你可以打开无限多的站点'
                ]),
                $.make('li', { className: 'NB-2' }, [
                  $.make('div', { className: 'NB-feedchooser-premium-bullet-image' }),
                  '网站更新速度提高 10x'
                ]),
                $.make('li', { className: 'NB-3' }, [
                  $.make('div', { className: 'NB-feedchooser-premium-bullet-image' }),
                  '文件夹也支持 River of News 阅读'
                ]),
                $.make('li', { className: 'NB-4' }, [
                  $.make('div', { className: 'NB-feedchooser-premium-bullet-image' }),
                  '你的 Zeitblog 可以设置为私有或受限访问'
                ]),
                $.make('li', { className: 'NB-5' }, [
                  $.make('div', { className: 'NB-feedchooser-premium-bullet-image' }),
                  '全文视图可以方便地提取出完整的文章'
                ])
//,
//                $.make('li', { className: 'NB-6' }, [
//                  $.make('div', { className: 'NB-feedchooser-premium-bullet-image' }),
//                  '喂养可怜而饥饿的小狗 Shiloh ',
//                  $.make('span', { className: 'NB-feedchooser-hungry-dog' }, '6 天'),
//                  $.make('img', { className: 'NB-feedchooser-premium-poor-hungry-dog', src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/shiloh.jpg' })
//                ])
              ]),

                $.make('div', { className: 'NB-static-form NB-stripe-form' }, [
                    $.make('label', '支付说明'),
                    $.make('label', { className: 'payextra-label', 'for': 'payextra' }, '普通帐户免费，高级帐户50元每年，欢迎一次购买多年，支付200元即可终身使用。<br><br>通过付费您能够为 NewsZeit 分担一点日益增长的费用，并且能够支持我们为 NewsZeit 开发更好的功能。<br><br>支持 “支付宝”、“淘宝” 和 “PayPal” 付款，付款时请在支付说明中写下你的帐号信息，我们会尽快为您开通。<br><br>'),
                    $.make('label', '支付宝'),
                    $.make('a', { href: 'https://me.alipay.com/bruceyou', target: '_blank' }, [
                        $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/alipay.png'}),
                    ]),

                    $.make('label', '淘宝'),
                    $.make('label', { className: 'payextra-label', 'for': 'payextra' }, '店铺链接'),
                    $.make('a', { href: 'http://shop105851433.taobao.com/', target: '_blank'}, 'http://shop105851433.taobao.com/'),

                    $.make('form', { action: 'https://www.paypal.com/cgi-bin/webscr', method: 'post', target: '_top' }, [
                        $.make('label', 'PayPal'),
                        $.make('input', { type: 'hidden', name: 'cmd', value: '_s-xclick'}),
                        $.make('input', { type: 'hidden', name: 'hosted_button_id', value: 'P7CJUARGHYCKU'}),
                        $.make('table', [
                            $.make('tr', [
                                $.make('td', [
                                    $.make('input', { type: 'hidden', name: 'on0', value: 'Purchase for'}, 'Purchase for'),
                                ]),
                            ]),
                            $.make('tr', [
                                $.make('td', [
                                    $.make('select', { name: 'os0' }, [
                                        $.make('option', { value: '1 Year'}, '1 Year $ 9.00 USD'),
                                        $.make('option', { value: 'Forever'}, 'Forever $ 36.00 USD'),
                                    ]),
                                ]),
                            ]),
                        ]),
                        $.make('input', { type: 'hidden', name: 'currency_code', value: 'USD'}),
                        $.make('label', ''),
                        $.make('input', { type: 'image', src: 'https://www.paypalobjects.com/zh_XC/C2/i/btn/btn_buynowCC_LG.gif', border: '0', name: 'submit', alt: 'PayPal——最安全便捷的在线支付方式！'}, [
                            $.make('img', { alt: '', border: '0', src: 'https://www.paypalobjects.com/zh_XC/i/scr/pixel.gif', width: '1', height: '1'}),
                        ]),
                    ]),
                ]),

/*
              $.make('div', { className: 'NB-modal-submit NB-modal-submit-paypal' }, [
                  $.make('div', { className: 'NB-feedchooser-payextra' }, [
                    $.make('input', { type: 'checkbox', name: 'payextra', id: 'NB-feedchooser-payextra-checkbox' }),
                    $.make('label', { 'for': 'NB-feedchooser-payextra-checkbox' }, 'I\'m feeling generous')
                  ]),
                  $.make('div', { className: 'NB-feedchooser-dollar' }, [
                      $.make('div', { className: 'NB-feedchooser-dollar-value NB-2' }, [
                          $.make('div', { className: 'NB-feedchooser-dollar-month' }, [
                            $.make('div', { className: 'NB-feedchooser-dollar-image' }, [
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/g_icn_coffeecup_gold16.png', style: "position: absolute; left: -56px;top: 15px;width: 16px;" }),
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/g_icn_coffeecup_gold24.png', style: "position: absolute; left: -31px;top: 10px; width: 24px;" }),
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/g_icn_coffeecup_gold32.png', style: "position: absolute; left: 0; top: 6px; width: 32px" })
                            ]),
                            '$24/year'
                          ]),
                          $.make('div', { className: 'NB-feedchooser-dollar-year' }, '($2/month)')
                      ]),
                      $.make('div', { className: 'NB-feedchooser-dollar-value NB-3' }, [
                          $.make('div', { className: 'NB-feedchooser-dollar-month' }, [
                            $.make('div', { className: 'NB-feedchooser-dollar-image' }, [
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/g_icn_coffeecup_gold24.png', style: "position: absolute; left: -68px;top: 11px;width: 24px;" }),
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/g_icn_coffeecup_gold32.png', style: "position: absolute; left: -42px;top: 7px; width: 32px;" }),
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/g_icn_coffeecup_gold40.png', style: "position: absolute; left: -8px; top: 4px; width: 40px" })
                            ]),
                            '$36/year'
                          ]),
                          $.make('div', { className: 'NB-feedchooser-dollar-year' }, '($3/month)')
                      ])
                  ]),
                  $.make('div', { className: 'NB-feedchooser-processor' }, [
                      $.make('div', { className: 'NB-feedchooser-paypal' }, [
                        $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/logo-paypal.png', height: 30 }),
                        $.make('div', { className: 'NB-feedchooser-paypal-form' })
                      ]),
                      $.make('div', { className: 'NB-feedchooser-stripe' }, [
                        $.make('div', { className: 'NB-creditcards' }, [
                            $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + "/img/reader/cc_visa.png" }),
                            $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + "/img/reader/cc_mastercard.png" }),
                            $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + "/img/reader/cc_amex.png" }),
                            $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + "/img/reader/cc_discover.png" })
                        ]),
                        $.make('div', { 
                            className: "NB-stripe-button NB-modal-submit-button NB-modal-submit-green"
                        }, [
                            "Pay by",
                            $.make('br'),
                            "Credit Card"
                        ])
                      ])
                  ])
              ]) */
            ])),
            (!this.options.premium_only && $.make('div', { className: 'NB-feedchooser-type NB-feedchooser-left'}, [
              (!NEWSBLUR.Globals.is_premium && $.make('div', { className: 'NB-feedchooser-info'}, [
                  $.make('div', { className: 'NB-feedchooser-info-type' }, [
                        $.make('span', { className: 'NB-feedchooser-subtitle-type-prefix' }, '免费'),
                        ' 标准帐户'
                  ]),
                    $.make('h2', { className: 'NB-modal-subtitle' }, [
                        $.make('b', [
                            '你最多可以打开 '+this.MAX_FEEDS+' 个站点。'
                        ]),
                        $.make('br'),
                        '你可以随时修改。'
                    ]),
                  $.make('div', { className: 'NB-feedchooser-info-counts'}),
                  $.make('div', { className: 'NB-feedchooser-info-sort'}, '根据流行程度自动选择'),
                  $.make('div', { className: 'NB-feedchooser-info-reset NB-splash-link'}, 'Reset to popular sites')
              ])),
              (this.options.chooser_only && $.make('div', { className: 'NB-feedchooser-info' }, [
                    $.make('h2', { className: 'NB-modal-title' }, [
                        $.make('div', { className: 'NB-icon' }),
                        '屏蔽站点',
                        $.make('div', { className: 'NB-icon-dropdown' })
                    ]),
                    $.make('div', { className: 'NB-feedchooser-info-reset NB-splash-link'}, 'Turn every site on'),
                    $.make('div', { className: 'NB-feedchooser-info-counts'})
              ])),
              this.make_feeds(),
              $.make('form', { className: 'NB-feedchooser-form' }, [
                  $.make('div', { className: 'NB-modal-submit' }, [
                      // $.make('div', { className: 'NB-modal-submit-or' }, 'or'),
                      $.make('input', { type: 'submit', disabled: 'true', className: 'NB-disabled NB-modal-submit-button NB-modal-submit-save NB-modal-submit-green', value: 'Check what you like above...' }),
                      $.make('input', { type: 'submit', className: 'NB-modal-submit-add NB-modal-submit-button NB-modal-submit-green', value: 'First, add sites' })
                  ])
              ]).bind('submit', function(e) {
                  e.preventDefault();
                  return false;
              })
            ]))
        ]);
    },
    
    make_paypal_button: function() {
        var self = this;
        var $paypal = $('.NB-feedchooser-paypal-form', this.$modal);
        $.get('/profile/paypal_form', function(response) {
          $paypal.html(response);
          self.choose_dollar_amount(2);
        });
    },
    
    make_google_button: function() {
      var checkout = '<script type="text/javascript" src="https://images-na.ssl-images-amazon.com/images/G/01/cba/js/widget/widget.js"></script><form method=POST action="https://payments.amazon.com/checkout/A215TOHXICT770"><input type="hidden" name="order-input" value="type:cba-signed-order/sha1-hmac/1;order:PD94bWwgdmVyc2lvbj0nMS4wJyBlbmNvZGluZz0nVVRGLTgnPz48T3JkZXIgeG1sbnM9J2h0dHA6Ly9wYXltZW50cy5hbWF6b24uY29tL2NoZWNrb3V0LzIwMDgtMTEtMzAvJz48Q2FydD48SXRlbXM+PEl0ZW0+PE1lcmNoYW50SWQ+QTIxNVRPSFhJQ1Q3NzA8L01lcmNoYW50SWQ+PFRpdGxlPk5ld3NCbHVyIFByZW1pdW0gLSAxIFllYXI8L1RpdGxlPjxEZXNjcmlwdGlvbj5UaGFuayB5b3UsIHRoYW5rIHlvdSwgdGhhbmsgeW91ITwvRGVzY3JpcHRpb24+PFByaWNlPjxBbW91bnQ+MTI8L0Ftb3VudD48Q3VycmVuY3lDb2RlPlVTRDwvQ3VycmVuY3lDb2RlPjwvUHJpY2U+PFF1YW50aXR5PjE8L1F1YW50aXR5PjxGdWxmaWxsbWVudE5ldHdvcms+TUVSQ0hBTlQ8L0Z1bGZpbGxtZW50TmV0d29yaz48L0l0ZW0+PC9JdGVtcz48L0NhcnQ+PC9PcmRlcj4=;signature:Zfg83JluKTIhItevtaGpspjdbfQ="><input alt="Checkout with Amazon Payments" src="https://payments.amazon.com/gp/cba/button?ie=UTF8&color=tan&background=white&cartOwnerId=A215TOHXICT770&size=large" type="image"></form>';
      var $checkout = $(checkout);
      return $checkout;
    },
    
    make_feeds: function() {
        var feeds = this.model.feeds;
        this.feed_count = _.unique(NEWSBLUR.assets.folders.feed_ids_in_folder()).length;
        
        var $feeds = new NEWSBLUR.Views.FeedList({
            feed_chooser: true
        }).make_feeds().$el;
        
        if ($feeds.data('sortable')) $feeds.data('sortable').disable();
        
        // Expand collapsed folders
        $('.NB-folder-collapsed', $feeds).css({
            'display': 'block',
            'opacity': 1
        }).removeClass('NB-folder-collapsed');
        
        // Pretend unfetched feeds are fine
        $('.NB-feed-unfetched', $feeds).removeClass('NB-feed-unfetched');

        // Make sure all folders are visible
        $('.NB-folder.NB-hidden', $feeds).removeClass('NB-hidden');
        
        $('.unread_count_positive', $feeds).text('On');
        $('.unread_count_negative', $feeds).text('Off');
        
        return $feeds;
    },

    resize_modal: function(previous_height) {
        var content_height = $('.NB-feedchooser-left', this.$modal).height() + 32;
        var container_height = this.$modal.parent().height();
        if (content_height > container_height && previous_height != content_height) {
            var chooser_height = $('#NB-feedchooser-feeds').height();
            var diff = Math.max(4, content_height - container_height);
            $('#NB-feedchooser-feeds').css({'max-height': chooser_height - diff});
            _.defer(_.bind(function() { this.resize_modal(content_height); }, this), 1);
        }
    },
    
    add_feed_to_decline: function(feed_id, update) {
        this.approve_list = _.without(this.approve_list, feed_id);
        var $feed = this.$feeds[feed_id];
        
        if (!$feed) return;
        
        $feed.removeClass('NB-feedchooser-approve');
        $feed.addClass('NB-feedchooser-decline');
        if (update) {
            this.update_counts();
        }
    },
    
    add_feed_to_approve: function(feed_id, update) {
        if (!_.contains(this.approve_list, feed_id)) {
            this.approve_list.push(feed_id);
        }
        var $feed = this.$feeds[feed_id];
        
        if (!$feed) return;
        
        $feed.removeClass('NB-feedchooser-decline');
        $feed.addClass('NB-feedchooser-approve');
        if (update) {
            this.update_counts();
        }
    },
        
    find_feeds_in_feed_list: function() {
        var self = this;
        var $feed_list = $('.NB-feedchooser', this.$modal);
        var $feeds = {};
        
        $('.feed', $feed_list).each(function() {
            var feed_id = parseInt($(this).data('id'), 10);
            if (!(feed_id in $feeds)) {
                $feeds[feed_id] = $([]);
            }
            $feeds[feed_id].push($(this).get(0));
        });

        // Remove invalid feeds that only show up in the assetmodel.
        // This occurs when a feed is still subscribed, but not in the user's folders.
        var found_feeds = _.uniq(_.keys($feeds)).sort();
        var invalid_feeds = _.each(self.model.feeds, function(feed_id) { 
            if (!_.contains(found_feeds, feed_id)) {
                delete self.model.feeds[feed_id];
            }
        });
        
        this.$feeds = $feeds;
    },
    
    update_counts: function(initial_load) {
        var $count = $('.NB-feedchooser-info-counts');
        var approved = this.approve_list.length;
        var $submit = $('.NB-modal-submit-save', this.$modal);
        var difference = approved - this.MAX_FEEDS;
        var muted = this.feed_count - approved;
        
        $count.text(approved + '/' + Inflector.commas(this.feed_count));

        if (NEWSBLUR.Globals.is_premium) {
            $submit.removeClass('NB-disabled').removeClass('NB-modal-submit-grey').attr('disabled', false);
            if (muted == 0) {
                $submit.val('打开全 部 ' + this.feed_count + ' 个站点');
            } else {
                $submit.val('屏蔽 ' + muted + ' 站点');
            }
            $count.toggleClass('NB-full', muted == 0);
        } else {
            $count.toggleClass('NB-full', approved == this.MAX_FEEDS);
            $count.toggleClass('NB-error', approved > this.MAX_FEEDS);

            if (!initial_load) {
                this.hide_autoselected_label();
            }
            if (approved > this.MAX_FEEDS) {
          $submit.addClass('NB-disabled').addClass('NB-modal-submit-grey').attr('disabled', true).val('你选择的站点数量已超出！ 请取消选择 ' + (
                difference == 1 ?
            '1 站点...' :
            difference + ' 站点...'
              ));
            } else {
          $submit.removeClass('NB-disabled').removeClass('NB-modal-submit-grey').attr('disabled', false).val('请打开这 '+ approved +' 个站点');
            }
        }
    },
    
    initial_load_feeds: function(reset) {
        var start = new Date();
        var self = this;
        var $feeds = $('.feed', this.$modal);
        var feeds = this.model.get_feeds();
        
        if (!feeds.size()) {
            _.defer(_.bind(function() {
                var $info = $('.NB-feedchooser-info', this.$modal);
                $('.NB-feedchooser-info-counts', $info).hide();
                $('.NB-feedchooser-info-sort', $info).hide();
                $('.NB-feedchooser-info-reset', $info).hide();
                $('#NB-feedchooser-feeds').hide();
                $('.NB-modal-submit-save').hide();
                $('.NB-modal-submit-add').show();
            }, this));
            return;
        }
        
        var active_feeds = feeds.any(function(feed) { return feed.get('active'); });
        if (!active_feeds || reset) {
            // Get feed subscribers bottom cut-off
            var min_subscribers = _.last(
              _.first(
                _.map(feeds.select(function(f) { return !f.has_exception; }), function(f) { return f.get('subs'); }).sort(function(a,b) { 
                  return b-a; 
                }), 
                this.MAX_FEEDS
              )
            );
        
            // Decline everything
            var approve_feeds = [];
            feeds.each(function(feed) {
                self.add_feed_to_decline(parseInt(feed.id, 10));
            
                if (feed.get('subs') >= min_subscribers) {
                    approve_feeds.push(parseInt(feed.id, 10));
                }
            });
        
            // Approve feeds in subs
            _.each(approve_feeds, function(feed_id) {
                if (feeds.get(feed_id).get('subs') > min_subscribers &&
                    self.approve_list.length < self.MAX_FEEDS &&
                    !self.model.get_feed(feed_id)['has_exception']) {
                    self.add_feed_to_approve(feed_id);
                }
            });
            _.each(approve_feeds, function(feed_id) {
                if (self.model.get_feed(feed_id).get('subs') == min_subscribers &&
                    self.approve_list.length < self.MAX_FEEDS) {
                    self.add_feed_to_approve(feed_id);
                }
            });
            
            this.show_autoselected_label();
        } else {
            // Get active feeds
            var active_feeds = _.pluck(feeds.select(function(feed) {
                return feed.get('active');
            }), 'id');
            this.approve_list = active_feeds;
            
            // Approve or decline
            var feeds = [];
            $feeds.each(function() {
                var feed_id = parseInt($(this).data('id'), 10);
                
                if (_.contains(active_feeds, feed_id)) {
                    self.add_feed_to_approve(feed_id);
                } else {
                    self.add_feed_to_decline(feed_id);
                }
            });
            
            _.defer(_.bind(function() { this.hide_autoselected_label(); }, this));
        }
        _.defer(_.bind(function() { this.update_counts(true); }, this));
    },
    
    show_autoselected_label: function() {
        $('.NB-feedchooser-info-reset', this.$modal).fadeOut(500, _.bind(function() {
            $('.NB-feedchooser-info-sort', this.$modal).fadeIn(500);
        }, this));
    },
    
    hide_autoselected_label: function() {
        $('.NB-feedchooser-info-sort', this.$modal).fadeOut(500, _.bind(function() {
            $('.NB-feedchooser-info-sort', this.$modal).hide();
            $('.NB-feedchooser-info-reset', this.$modal).fadeIn(500);
        }, this));
    },
    
    save: function() {
        var self = this;
        var approve_list = this.approve_list;
        var $submit = $('.NB-modal-submit-save', this.$modal);
        $submit.addClass('NB-disabled').removeClass('NB-modal-submit-green').val('Saving...');
        
        NEWSBLUR.reader.flags['reloading_feeds'] = true;
        this.model.save_feed_chooser(approve_list, function() {
            self.flags['has_saved'] = true;
            NEWSBLUR.reader.flags['reloading_feeds'] = false;
            NEWSBLUR.reader.hide_feed_chooser_button();
            NEWSBLUR.assets.load_feeds();
            $.modal.close();
        });
    },
    
    close_and_add: function() {
        $.modal.close(function() {
            NEWSBLUR.add_feed = new NEWSBLUR.ReaderAddFeed();
        });
    },
    
    open_stripe_form: function() {
        window.location.href = "https://" + NEWSBLUR.URLs.domain + "/profile/stripe_form?plan=" + this.plan;
    },
    
    choose_dollar_amount: function(plan) {
        var $value = $('.NB-feedchooser-dollar-value', this.$modal);
        var $input = $('input[name=a3]');
        var $days = $('.NB-feedchooser-hungry-dog', this.$modal);
        
        this.plan = plan;

        $value.removeClass('NB-selected');
        $value.filter('.NB-'+plan).addClass('NB-selected');
        if (plan == 1) {
            $input.val(12);
            $days.text('6 天');
        } else if (plan == 2) {
            $input.val(24);
            $days.text('12 天');
        } else if (plan == 3) {
            $input.val(36);
            $days.text('18 天');
        }
    },
    
    switch_payextra: function() {
        var $payextra = $("input[name=payextra]", this.$modal);
        var selected = $payextra.is(':checked');
        
        if (selected) {
            this.choose_dollar_amount(3);
        } else {
            this.choose_dollar_amount(2);
        }
    },
    
    // ===========
    // = Actions =
    // ===========

    handle_mousedown: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.feed' }, _.bind(function($t, $p) {
            e.preventDefault();
            
            var feed_id = parseInt($t.attr('data-id'), 10);
            if (_.contains(this.approve_list, feed_id)) {
                this.add_feed_to_decline(feed_id, true);
            } else {
                this.add_feed_to_approve(feed_id, true);
            }
        }, this));
        
        $.targetIs(e, { tagSelector: '.NB-modal-submit-save' }, _.bind(function($t, $p) {
            e.preventDefault();
            this.save();
        }, this));
              
        $.targetIs(e, { tagSelector: '.NB-modal-submit-add' }, _.bind(function($t, $p) {
            e.preventDefault();
            this.close_and_add();
        }, this));
        
        $.targetIs(e, { tagSelector: '.NB-stripe-button' }, _.bind(function($t, $p) {
            e.preventDefault();
            this.open_stripe_form();
        }, this));
        
        $.targetIs(e, { tagSelector: '.NB-feedchooser-info-reset' }, _.bind(function($t, $p) {
            e.preventDefault();
            this.initial_load_feeds(true);
        }, this));
        
        $.targetIs(e, { tagSelector: '.NB-feedchooser-dollar-value' }, _.bind(function($t, $p) {
            e.preventDefault();
            var step;
            if ($t.hasClass('NB-1')) {
                step = 1;
            } else if ($t.hasClass('NB-2')) {
                step = 2;
            } else if ($t.hasClass('NB-3')) {
                step = 3;
            }
            this.choose_dollar_amount(step);
        }, this));
    },
    
    handle_change: function(elem, e) {
                
        $.targetIs(e, { tagSelector: 'input[name=payextra]' }, _.bind(function($t, $p) {
            e.preventDefault();
            this.switch_payextra();
        }, this));
        
    },

    handle_cancel: function() {
        var $cancel = $('.NB-modal-cancel', this.$modal);
        
        $cancel.click(function(e) {
            e.preventDefault();
            $.modal.close();
        });
    }
                
});
