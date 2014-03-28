//
//  AJKMainViewController.m
//  MapAnnotationDemo
//
//  Created by shan xu on 14-3-28.
//  Copyright (c) 2014年 夏至. All rights reserved.
//

#import "AJKMainViewController.h"
#import "MapViewController.h"

@interface AJKMainViewController ()

@end

@implementation AJKMainViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.title = @"Map Annotation Demo";
   
    UITableView *tableList = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 504) style:UITableViewStylePlain];
    tableList.dataSource = self;
    tableList.delegate = self;
    [self.view addSubview:tableList];
}

#pragma UITableView Delegate
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 44.0;
}
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return 2;
}
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString *identifer = @"cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifer];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifer];
    }
    
    if (indexPath.row == 0) {
        cell.textLabel.text = @"Navi";
    }else{
        cell.textLabel.text = @"Map Choose";
    }
    
    return cell;
}
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    if (indexPath.row == 0) {
        
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                             @"中国上海市陆家嘴延安东路",@"address",
                             @"上海市",@"city",
                             @"google",@"from_map_type",
                             @"31.23733484",@"google_lat",
                             @"121.50142656",@"google_lng",
                             @"浦东新区",@"region", nil];
        
        
        MapViewController *mv = [[MapViewController alloc] init];
        mv.navDic = dic;
        mv.mapType = RegionNavi;
        [self.navigationController pushViewController:mv animated:YES];
    }else{
        MapViewController *mv = [[MapViewController alloc] init];
        mv.siteDelegate = self;
        [mv setHidesBottomBarWhenPushed:YES];
        mv.mapType = RegionChoose;
        [self.navigationController pushViewController:mv animated:YES];
    }
}
-(void)loadMapSiteMessage:(NSDictionary *)mapSiteDic{
    
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
