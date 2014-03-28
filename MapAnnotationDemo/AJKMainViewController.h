//
//  AJKMainViewController.h
//  MapAnnotationDemo
//
//  Created by shan xu on 14-3-28.
//  Copyright (c) 2014年 夏至. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MapViewController.h"

@interface AJKMainViewController : UIViewController<UITableViewDataSource,UITableViewDelegate,MapViewControllerDelegate>


-(void)loadMapSiteMessage:(NSDictionary *)mapSiteDic;
@end
