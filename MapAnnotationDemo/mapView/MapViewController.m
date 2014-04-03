//
//  MapViewController.m
//  AnjukeBroker_New
//
//  Created by shan xu on 14-3-18.
//  Copyright (c) 2014年 Wu sicong. All rights reserved.
//

#import "MapViewController.h"
#import "RegionAnnotation.h"
#import "RegexKitLite.h"
#import "CheckInstalledMapAPP.h"
#import "LocationChange.h"
#import "LocIsBaidu.h"
//#import "NSString+RTStyle.h"

#define SYSTEM_NAVIBAR_COLOR [UIColor colorWithRed:0 green:0 blue:0 alpha:1]
#define ISIOS7 ([[[[UIDevice currentDevice] systemVersion] substringToIndex:1] intValue]>=7)
#define ISIOS6 ([[[[UIDevice currentDevice] systemVersion] substringToIndex:1] intValue]>=6)
#define STATUS_BAR_H 20
#define NAV_BAT_H 44

#define FRAME_WITH_NAV CGRectMake(0, 64, [self windowWidth], [self windowHeight] - STATUS_BAR_H - NAV_BAT_H)
#define FRAME_USER_LOC CGRectMake(8, [self windowHeight] - STATUS_BAR_H - NAV_BAT_H-58+64, 40, 40)
#define FRAME_CENTRE_LOC CGRectMake([self windowWidth]/2-8, ([self windowHeight] - STATUS_BAR_H - NAV_BAT_H)/2-25+64, 16, 33)


@interface MapViewController ()
//导航目的地2d,百度
@property(nonatomic,assign) CLLocationCoordinate2D naviCoordsBd;
//导航目的地2d,高德
@property(nonatomic,assign) CLLocationCoordinate2D naviCoordsGd;
//user最新2d
@property(nonatomic,assign) CLLocationCoordinate2D nowCoords;
//最近一次成功查询2d
@property(nonatomic,assign) CLLocationCoordinate2D lastCoords;
//最近一次请求的中心2d
@property(nonatomic,assign) CLLocationCoordinate2D centerCoordinate;
@property(nonatomic,strong) NSMutableArray *requestLocArr;
@property(nonatomic,strong) MKMapView *regionMapView;
//updateInt初始化为0，大于1时，didUpdateUserLocation中setRegion不再执行
@property(nonatomic,assign) int updateInt;
//userRegion 地图中心点定位参数
@property(nonatomic,assign) MKCoordinateRegion userRegion;
@property(nonatomic,assign) MKCoordinateRegion naviRegion;

@property(nonatomic,strong) NSString *city;
@property(nonatomic,strong) NSArray *routes;//ios6路线arr
//地图的区域和详细地址
@property(nonatomic,strong) NSString *regionStr;
@property(nonatomic,strong) NSString *addressStr;
@property(nonatomic,strong) CLLocationManager *locationManager;
//定位参数信息
@property(nonatomic,strong) RegionAnnotation *regionAnnotation;
//定位状态，包括6种状态
@property(nonatomic, assign) int loadStatus;
@end

@implementation MapViewController
@synthesize mapType;
@synthesize regionMapView;
@synthesize addressStr;
@synthesize updateInt;
@synthesize userRegion;
@synthesize naviRegion;
@synthesize lastCoords;
@synthesize naviCoordsBd;
@synthesize naviCoordsGd;
@synthesize nowCoords;
@synthesize routes;
@synthesize regionStr;
@synthesize navDic;
@synthesize requestLocArr;
@synthesize centerCoordinate;
@synthesize locationManager;
@synthesize regionAnnotation;
@synthesize loadStatus;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        self.updateInt = 0;
        self.navDic = [[NSDictionary alloc] init];
        self.requestLocArr = [[NSMutableArray alloc] init];
    }
    return self;
}
- (NSInteger)windowWidth {
    return [[[[UIApplication sharedApplication] windows] objectAtIndex:0] frame].size.width;
}
- (NSInteger)windowHeight {
    return [[[[UIApplication sharedApplication] windows] objectAtIndex:0] frame].size.height;
}
- (void)viewDidDisappear:(BOOL)animated{
    self.regionMapView.delegate = nil;
    self.locationManager.delegate = nil;
}
- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    if (ISIOS7) {
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    }
    [self addBackButton];
    NSString *titStr;
    if (self.mapType == RegionNavi) {
        titStr = @"查看地理位置";
    }else{
        titStr = @"位置";
        [self addRightButton];
    }
    
    UILabel *lb = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 120, 31)];
    lb.backgroundColor = [UIColor clearColor];
    lb.font = [UIFont systemFontOfSize:19];
    lb.textAlignment = NSTextAlignmentCenter;
    lb.textColor = SYSTEM_NAVIBAR_COLOR;
    lb.text = titStr;
    self.navigationItem.titleView = lb;
    
    self.regionMapView = [[MKMapView alloc] initWithFrame:FRAME_WITH_NAV];
    self.regionMapView.delegate = self;
    self.regionMapView.showsUserLocation = YES;
    [self.view addSubview:self.regionMapView];
 
    self.locationManager = [CLLocationManager new];
    [self.locationManager setDelegate:self];
    [self.locationManager setDesiredAccuracy:kCLLocationAccuracyBest];
    [self.locationManager setDistanceFilter:kCLDistanceFilterNone];
    [self.locationManager startUpdatingLocation];
    
    UIButton *goUserLocBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    goUserLocBtn.frame = FRAME_USER_LOC;
    [goUserLocBtn addTarget:self action:@selector(goUserLoc:) forControlEvents:UIControlEventTouchUpInside];
    [goUserLocBtn setImage:[UIImage imageNamed:@"wl_map_icon_position.png"] forState:UIControlStateNormal];
    [goUserLocBtn setImage:[UIImage imageNamed:@"wl_map_icon_position_press.png"] forState:UIControlStateHighlighted];
    goUserLocBtn.backgroundColor = [UIColor clearColor];
    [self.view addSubview:goUserLocBtn];
    
    if (self.mapType == RegionChoose) {
        UIImageView *certerIcon = [[UIImageView alloc] initWithFrame:FRAME_CENTRE_LOC];
        certerIcon.image = [UIImage imageNamed:@"anjuke_icon_itis_position.png"];
        [self.view addSubview:certerIcon];
    }else{
        [self getChangedLoc];
        CLLocation *loc = [[CLLocation alloc] initWithLatitude:naviCoordsGd.latitude longitude:naviCoordsGd.longitude];
        MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(naviCoordsGd, 500, 500);
        self.naviRegion = [self.regionMapView regionThatFits:viewRegion];
        
        [self.regionMapView setRegion:self.naviRegion animated:NO];
        [self showAnnotation:loc coord:naviCoordsGd];

        if (!ISIOS6) {
            [self performSelector:@selector(setRegionAgain) withObject:nil afterDelay:2.0];
        }
    }
}
-(void)setRegionAgain{
    MKCoordinateRegion viewRegion1 = MKCoordinateRegionMakeWithDistance(naviCoordsGd, 200, 200);
    self.naviRegion = [self.regionMapView regionThatFits:viewRegion1];
    [self.regionMapView setRegion:self.naviRegion animated:NO];
}
#pragma mark - 百度和火星经纬度转换
-(void)getChangedLoc{
    if ([LocIsBaidu locIsBaid:self.navDic]) {
        
        naviCoordsBd.latitude = [[self.navDic objectForKey:@"baidu_lat"] doubleValue];
        naviCoordsBd.longitude = [[self.navDic objectForKey:@"baidu_lng"] doubleValue];
        
        double gdLat,gdLon;
        bd_decrypt(naviCoordsBd.latitude, naviCoordsBd.longitude, &gdLat, &gdLon);
        
        naviCoordsGd.latitude = gdLat;
        naviCoordsGd.longitude = gdLon;
    }else{
        naviCoordsGd.latitude = [[self.navDic objectForKey:@"google_lat"] doubleValue];
        naviCoordsGd.longitude = [[self.navDic objectForKey:@"google_lng"] doubleValue];
        
        double bdLat,bdLon;
        bd_encrypt(naviCoordsGd.latitude, naviCoordsGd.longitude, &bdLat, &bdLon);
        
        naviCoordsBd.latitude = bdLat;
        naviCoordsBd.longitude = bdLon;
    }
}
-(void)openGPSTips{
    UIAlertView *alet = [[UIAlertView alloc] initWithTitle:@"当前定位服务不可用" message:@"请到“设置->隐私->定位服务”中开启定位" delegate:self cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
    [alet show];
}
#pragma UIAlertViewDelegate
-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    if (self.mapType == RegionChoose) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}
-(void)addRightButton{
    UIBarButtonItem *rBtn = [[UIBarButtonItem alloc] initWithTitle:@"发送" style:UIBarButtonItemStylePlain target:self action:@selector(rightButtonAction:)];
    if (!ISIOS7) {
        self.navigationItem.rightBarButtonItem = rBtn;
    }
    else {
        [self.navigationController.navigationBar setTintColor:SYSTEM_NAVIBAR_COLOR];
        self.navigationItem.rightBarButtonItem = rBtn;
    }
}
- (void)addBackButton {
    // 设置返回btn
    UIImage *image = [UIImage imageNamed:@"anjuke_icon_back.png"];
    UIImage *highlighted = [UIImage imageNamed:@"anjuke_icon_back.png"];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0, 0, image.size.width + 40 , 44);
    [button addTarget:self action:@selector(doBack:) forControlEvents:UIControlEventTouchUpInside];
    [button setImage:image forState:UIControlStateNormal];
    [button setImage:highlighted forState:UIControlStateHighlighted];
    [button setImageEdgeInsets:UIEdgeInsetsMake(0, 0, 0, 40)];
    [button setTitle:@"返回" forState:UIControlStateNormal];
    [button setTitle:@"返回" forState:UIControlStateHighlighted];
    [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [button setTitleColor:[UIColor blackColor] forState:UIControlStateHighlighted];
    button.titleLabel.textAlignment = NSTextAlignmentLeft;
    button.titleLabel.backgroundColor = [UIColor clearColor];
    button.backgroundColor = [UIColor clearColor];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:button];
}
-(void)doBack:(id)sender{
    [self.navigationController popViewControllerAnimated:YES];
}
-(void)rightButtonAction:(id)sender{
    if (lastCoords.latitude && lastCoords.longitude) {
        if (self.siteDelegate && [self.siteDelegate respondsToSelector:@selector(loadMapSiteMessage:)]){
            NSMutableDictionary *locationDic = [[NSMutableDictionary alloc] init];
            [locationDic setValue:self.addressStr forKey:@"address"];
            [locationDic setValue:self.city forKey:@"city"];
            [locationDic setValue:self.regionStr forKey:@"region"];
            [locationDic setValue:[NSString stringWithFormat:@"%.8f",lastCoords.latitude] forKey:@"google_lat"];
            [locationDic setValue:[NSString stringWithFormat:@"%.8f",lastCoords.longitude] forKey:@"google_lng"];
            [locationDic setValue:@"google" forKey:@"from_map_type"];
                        
           [self.siteDelegate loadMapSiteMessage:locationDic];
        }
        [self.navigationController popViewControllerAnimated:YES];
    }
}

-(void)goUserLoc:(id)sender{
    [self.regionMapView setRegion:self.userRegion animated:YES];
}

-(void)doAcSheet{
    NSArray *appListArr = [CheckInstalledMapAPP checkHasOwnApp];
    NSString *sheetTitle = [NSString stringWithFormat:@"导航到 %@",[self.navDic objectForKey:@"address"]];

    UIActionSheet *sheet;
    if ([appListArr count] == 2) {
        sheet = [[UIActionSheet alloc] initWithTitle:sheetTitle delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:appListArr[0],appListArr[1], nil];
    }else if ([appListArr count] == 3){
        sheet = [[UIActionSheet alloc] initWithTitle:sheetTitle delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:appListArr[0],appListArr[1],appListArr[2], nil];
    }else if ([appListArr count] == 4){
        sheet = [[UIActionSheet alloc] initWithTitle:sheetTitle delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:appListArr[0],appListArr[1],appListArr[2],appListArr[3], nil];
    }else if ([appListArr count] == 5){
        sheet = [[UIActionSheet alloc] initWithTitle:sheetTitle delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:appListArr[0],appListArr[1],appListArr[2],appListArr[3],appListArr[4], nil];
    }
    sheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
    [sheet showInView:self.view];
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
    
    NSString *btnTitle = [actionSheet buttonTitleAtIndex:buttonIndex];
    if (buttonIndex == 0) {
        if (!ISIOS6) {//ios6 调用goole网页地图
            NSString *urlString = [[NSString alloc]
                                   initWithFormat:@"http://maps.google.com/maps?saddr=&daddr=%.8f,%.8f&dirfl=d",self.naviCoordsGd.latitude,self.naviCoordsGd.longitude];
            
            NSURL *aURL = [NSURL URLWithString:urlString];
            [[UIApplication sharedApplication] openURL:aURL];
        }else{//ios7 跳转apple map
            CLLocationCoordinate2D to;
            
            to.latitude = naviCoordsGd.latitude;
            to.longitude = naviCoordsGd.longitude;
            MKMapItem *currentLocation = [MKMapItem mapItemForCurrentLocation];
            MKMapItem *toLocation = [[MKMapItem alloc] initWithPlacemark:[[MKPlacemark alloc] initWithCoordinate:to addressDictionary:nil]];
            
            toLocation.name = addressStr;
            [MKMapItem openMapsWithItems:[NSArray arrayWithObjects:currentLocation, toLocation, nil] launchOptions:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:MKLaunchOptionsDirectionsModeDriving, [NSNumber numberWithBool:YES], nil] forKeys:[NSArray arrayWithObjects:MKLaunchOptionsDirectionsModeKey, MKLaunchOptionsShowsTrafficKey, nil]]];
        }
    }
    if ([btnTitle isEqualToString:@"google地图"]) {
        NSString *urlStr = [NSString stringWithFormat:@"comgooglemaps://?saddr=%.8f,%.8f&daddr=%.8f,%.8f&directionsmode=transit",self.nowCoords.latitude,self.nowCoords.longitude,self.naviCoordsGd.latitude,self.naviCoordsGd.longitude];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlStr]];
    }else if ([btnTitle isEqualToString:@"高德地图"]){
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"iosamap://navi?sourceApplication=broker&backScheme=openbroker2&poiname=%@&poiid=BGVIS&lat=%.8f&lon=%.8f&dev=1&style=2",self.addressStr,self.naviCoordsGd.latitude,self.naviCoordsGd.longitude]];
        [[UIApplication sharedApplication] openURL:url];
        
    }else if ([btnTitle isEqualToString:@"百度地图"]){
        double bdNowLat,bdNowLon;
        bd_encrypt(self.nowCoords.latitude, self.nowCoords.longitude, &bdNowLat, &bdNowLon);

        NSString *stringURL = [NSString stringWithFormat:@"baidumap://map/direction?origin=%.8f,%.8f&destination=%.8f,%.8f&&mode=driving",bdNowLat,bdNowLon,self.naviCoordsBd.latitude,self.naviCoordsBd.longitude];
        NSURL *url = [NSURL URLWithString:stringURL];
        [[UIApplication sharedApplication] openURL:url];
    }else if ([btnTitle isEqualToString:@"显示路线"]){
        [self drawRout];
    }
}
-(void)drawRout{
    MKPlacemark *fromPlacemark = [[MKPlacemark alloc] initWithCoordinate:nowCoords addressDictionary:nil];
    MKPlacemark *toPlacemark   = [[MKPlacemark alloc] initWithCoordinate:naviCoordsGd addressDictionary:nil];
    MKMapItem *fromItem = [[MKMapItem alloc] initWithPlacemark:fromPlacemark];
    MKMapItem *toItem   = [[MKMapItem alloc] initWithPlacemark:toPlacemark];
    
    [self.regionMapView removeOverlays:self.regionMapView.overlays];

    if (ISIOS7) {//ios7采用系统绘制方法
        [self.regionMapView removeOverlays:self.regionMapView.overlays];
        [self findDirectionsFrom:fromItem to:toItem];
    }else{//ios7以下借用google路径绘制方法
        if (routes) {
            routes = nil;
        }
        routes = [self calculateRoutesFrom];
        [self updateRouteView];
        [self centerMap];
    }
}
#pragma mark- ios6绘制路线方法
-(NSArray*)calculateRoutesFrom{
	NSString* apiUrlStr = [NSString stringWithFormat:@"http://maps.google.com/maps?output=dragdir&saddr=%0.8f,%0.8f&daddr=%0.8f,%0.8f", self.nowCoords.latitude, self.nowCoords.longitude, self.naviCoordsGd.latitude, self.naviCoordsGd.longitude];
	NSURL* apiUrl = [NSURL URLWithString:apiUrlStr];
    NSString *apiResponse = [NSString stringWithContentsOfURL:apiUrl encoding:NSASCIIStringEncoding error:nil];
    
    NSString* encodedPoints = [apiResponse stringByMatching:@"points:\\\"([^\\\"]*)\\\"" capture:1L];
	return [self decodePolyLine:[encodedPoints mutableCopy]:self.nowCoords to:self.naviCoordsGd];
}
//ios6 路线绘图，创建PolyLine
-(NSMutableArray *)decodePolyLine: (NSMutableString *)encoded :(CLLocationCoordinate2D)f to: (CLLocationCoordinate2D) t {
    [encoded replaceOccurrencesOfString:@"\\\\" withString:@"\\"
								options:NSLiteralSearch
								  range:NSMakeRange(0, [encoded length])];
	NSInteger len = [encoded length];
	NSInteger index = 0;
	NSMutableArray *array = [[NSMutableArray alloc] init];
	NSInteger latV = 0;
	NSInteger lngV = 0;
	while (index < len) {
		NSInteger b;
		NSInteger shift = 0;
		NSInteger result = 0;
		do {
			b = [encoded characterAtIndex:index++] - 63;
			result |= (b & 0x1f) << shift;
			shift += 5;
		} while (b >= 0x20);
		NSInteger dlat = ((result & 1) ? ~(result >> 1) : (result >> 1));
		latV += dlat;
		shift = 0;
		result = 0;
		do {
			b = [encoded characterAtIndex:index++] - 63;
			result |= (b & 0x1f) << shift;
			shift += 5;
		} while (b >= 0x20);
		NSInteger dlng = ((result & 1) ? ~(result >> 1) : (result >> 1));
		lngV += dlng;
		NSNumber *latitude = [[NSNumber alloc] initWithFloat:latV * 1e-5];
		NSNumber *longitude = [[NSNumber alloc] initWithFloat:lngV * 1e-5];
		CLLocation *loc = [[CLLocation alloc] initWithLatitude:[latitude floatValue] longitude:[longitude floatValue]];
		[array addObject:loc];
	}
    CLLocation *first = [[CLLocation alloc] initWithLatitude:[[NSNumber numberWithFloat:f.latitude] floatValue] longitude:[[NSNumber numberWithFloat:f.longitude] floatValue] ];
    CLLocation *end = [[CLLocation alloc] initWithLatitude:[[NSNumber numberWithFloat:t.latitude] floatValue] longitude:[[NSNumber numberWithFloat:t.longitude] floatValue] ];
	[array insertObject:first atIndex:0];
    [array addObject:end];
	return array;
}
//ios6绘图结束后，定位路线中心
-(void)centerMap {
	MKCoordinateRegion region;
    
	CLLocationDegrees maxLat = -90;
	CLLocationDegrees maxLon = -180;
	CLLocationDegrees minLat = 90;
	CLLocationDegrees minLon = 180;
	for(int idx = 0; idx < routes.count; idx++)
	{
		CLLocation* currentLocation = [routes objectAtIndex:idx];
		if(currentLocation.coordinate.latitude > maxLat)
			maxLat = currentLocation.coordinate.latitude;
		if(currentLocation.coordinate.latitude < minLat)
			minLat = currentLocation.coordinate.latitude;
		if(currentLocation.coordinate.longitude > maxLon)
			maxLon = currentLocation.coordinate.longitude;
		if(currentLocation.coordinate.longitude < minLon)
			minLon = currentLocation.coordinate.longitude;
	}
	region.center.latitude     = (maxLat + minLat) / 2;
	region.center.longitude    = (maxLon + minLon) / 2;
	region.span.latitudeDelta  = maxLat - minLat + 0.018;
	region.span.longitudeDelta = maxLon - minLon + 0.018;
    
	[self.regionMapView setRegion:region animated:YES];
}
-(void)updateRouteView {
    CLLocationCoordinate2D pointsToUse[[routes count]];
    for (int i = 0; i < [routes count]; i++) {
        CLLocationCoordinate2D coords;
        CLLocation *loc = [routes objectAtIndex:i];
        coords.latitude = loc.coordinate.latitude;
        coords.longitude = loc.coordinate.longitude;
        pointsToUse[i] = coords;
    }
    MKPolyline *lineOne = [MKPolyline polylineWithCoordinates:pointsToUse count:[routes count]];
    [self.regionMapView addOverlay:lineOne];
}
-(MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id <MKOverlay>)overlay{
    if ([overlay isKindOfClass:[MKPolyline class]]){
        MKPolylineView *lineview=[[MKPolylineView alloc] initWithOverlay:overlay] ;
        //路线颜色
        lineview.strokeColor=[UIColor redColor];
        lineview.lineWidth = 5.0;
        return lineview;
    }
    return nil;
}

#pragma mark - ios7路线绘制方法
-(void)findDirectionsFrom:(MKMapItem *)from to:(MKMapItem *)to{
    MKDirectionsRequest *request = [[MKDirectionsRequest alloc] init];
    request.source = from;
    request.destination = to;
    request.transportType = MKDirectionsTransportTypeWalking;
    if (ISIOS7) {
        request.requestsAlternateRoutes = YES;
    }
    
    MKDirections *directions = [[MKDirections alloc] initWithRequest:request];
    //ios7获取绘制路线的路径方法
    [directions calculateDirectionsWithCompletionHandler:^(MKDirectionsResponse *response, NSError *error) {
         if (error) {
             NSLog(@"error:%@", error);
         }
         else {
             MKRoute *route = response.routes[0];
             [self.regionMapView addOverlay:route.polyline];
         }
     }];
}
- (MKOverlayRenderer *)mapView:(MKMapView *)mapView
            rendererForOverlay:(id<MKOverlay>)overlay{
    MKPolylineRenderer *renderer = [[MKPolylineRenderer alloc] initWithOverlay:overlay];
    renderer.lineWidth = 5.0;
    renderer.strokeColor = [UIColor redColor];
    return renderer;
}
#pragma mark - 检测应用是否开启定位服务
- (void)locationManager: (CLLocationManager *)manager
       didFailWithError: (NSError *)error {
    [manager stopUpdatingLocation];
    switch([error code]) {
        case kCLErrorDenied:
            [self openGPSTips];
            break;
        case kCLErrorLocationUnknown:
            break;
        default:
            break;
    }
}

#pragma mark MKMapViewDelegate -user location定位变化
-(void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation{
    self.nowCoords = [userLocation coordinate];
    //放大地图到自身的经纬度位置。
    self.userRegion = MKCoordinateRegionMakeWithDistance(self.nowCoords, 200, 200);

    if (self.mapType != RegionNavi) {
        if (self.updateInt >= 1) {
            return;
        }
        [self showAnnotation:userLocation.location coord:self.nowCoords];
        [self.regionMapView setRegion:self.userRegion animated:NO];
    }
}
-(void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated{
    if (self.mapType == RegionNavi) {
        return;
    }
    if (ISIOS7) {
        if ([mapView.annotations count]) {
            [mapView removeAnnotations:mapView.annotations];
        }
    }

    if (self.updateInt == 0){
        return;
    }
    self.centerCoordinate = mapView.region.center;
    
    CLLocation *loc = [[CLLocation alloc] initWithLatitude:self.centerCoordinate.latitude longitude:self.centerCoordinate.longitude];
    
    [self showAnnotation:loc coord:centerCoordinate];
}
- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated{
    if (self.mapType == RegionNavi) {
        return;
    }
    if (ISIOS7) {
        if ([mapView.annotations count]) {
            [mapView removeAnnotations:mapView.annotations];
        }
    }
}
#pragma mark- 获取位置信息，并判断是否显示，block方法支持ios6及以上
-(void)showAnnotation:(CLLocation *)location coord:(CLLocationCoordinate2D)coords{
    self.updateInt += 1;
    if (self.mapType == RegionNavi && ![[self.navDic objectForKey:@"region"] isEqualToString:@""]) {
        loadStatus = 4;
        [self addAnnotationView:location coord:coords region:[self.navDic objectForKey:@"region"]  address:[self.navDic objectForKey:@"address"]];
        return;
    }
    
    //每次请求位置时，把latitude塞入arr。在block回掉时判断但会latitude是否存在arr且和最近一次请求latitude一致。如果一致，则显示，否则舍弃
    [self.requestLocArr addObject:[NSString stringWithFormat:@"%.8f",[location coordinate].latitude]];
    self.regionStr = @"";
    self.addressStr = @"";
    self.city = @"";
    self.lastCoords = coords;
    if (self.mapType == RegionChoose) {
        loadStatus = 0;
    }else{
        loadStatus = 3;
    }
    [self addAnnotationView:location coord:coords region:@"加载地址中..." address:nil];
    
    //CLGeocoder ios5之后支持
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray *array, NSError *error) {
        //判断返回loc和当前最后一次请求loc的latitude是否一致，否则不返回位置信息
        if (![[NSString stringWithFormat:@"%0.8f",[location coordinate].latitude] isEqualToString:[NSString stringWithFormat:@"%0.8f",self.centerCoordinate.latitude]] && self.mapType == RegionChoose && self.updateInt >= 2) {
            [self.requestLocArr removeObject:[NSString stringWithFormat:@"%0.8f",[location coordinate].latitude]];
            return;
        }
        if ([self.requestLocArr count] > 0) {
            [self.requestLocArr removeAllObjects];
        }
        if (array.count > 0) {
            CLPlacemark *placemark = [array objectAtIndex:0];
            
            NSString *region = [placemark.addressDictionary objectForKey:@"SubLocality"];
            NSString *address = [placemark.addressDictionary objectForKey:@"Name"];
            self.regionStr = region;
            self.addressStr = address;
            self.city = placemark.administrativeArea ? placemark.administrativeArea : @"";
            
            if (mapType == RegionChoose) {
                loadStatus = 1;
            }else{
                loadStatus = 4;
            }
            [self addAnnotationView:location coord:coords region:region address:address];
        }else{
            self.regionStr = @"";
            self.addressStr = @"";
            self.city = @"";
            
            if (mapType == RegionChoose) {
                loadStatus = 2;
            }else{
                loadStatus = 5;
            }
            [self addAnnotationView:location coord:coords region:@"没有找到有效地址" address:nil];
        }
    }];
}
#pragma mark- 添加大头针的标注
-(void)addAnnotationView:(CLLocation *)location coord:(CLLocationCoordinate2D)coords region:(NSString *)region address:(NSString *)address{
    if ([self.regionMapView.annotations count]) {
        [self.regionMapView removeAnnotations:self.regionMapView.annotations];
    }

    if (!self.regionAnnotation) {
        self.regionAnnotation = [[RegionAnnotation alloc] init];
    }
    
    self.regionAnnotation.coordinate = coords;
    self.regionAnnotation.title = region;
    self.regionAnnotation.subtitle  = address;
    
    if (loadStatus == 0) {
        self.regionAnnotation.annotationStatus = ChooseLoading;
    }else if (loadStatus == 1){
        self.regionAnnotation.annotationStatus = ChooseSuc;
    }else if (loadStatus == 2){
        self.regionAnnotation.annotationStatus = ChooseFail;
    }else if (loadStatus == 3){
        self.regionAnnotation.annotationStatus = NaviLoading;
    }else if (loadStatus == 4){
        self.regionAnnotation.annotationStatus = NaviSuc;
    }else if (loadStatus == 5){
        self.regionAnnotation.annotationStatus = NaviFail;
    }
    [self.regionMapView addAnnotation:self.regionAnnotation];
    [self.regionMapView selectAnnotation:self.regionAnnotation animated:YES];
}

#pragma mark MKMapViewDelegate -显示大头针标注
-(MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation{
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        return nil;
    }
    if ([annotation isKindOfClass:[regionAnnotation class]]) {
        static NSString* identifier = @"MKAnnotationView";
        RegionAnnotationView *annotationView;
        
        annotationView = (RegionAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:identifier];
        
        if (!annotationView) {
            annotationView = [[RegionAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:identifier];
            annotationView.acSheetDelegate = self;
        }

        annotationView.backgroundColor = [UIColor clearColor];
        annotationView.annotation = annotation;
        [annotationView layoutSubviews];
        [annotationView setCanShowCallout:NO];
        
        return annotationView;
    }else{
        return nil;
    }
}
-(void)naviClick{
    [self doAcSheet];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
