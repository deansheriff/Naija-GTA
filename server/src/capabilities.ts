import {CAMPAIGN_VERSION,missionOrder} from './campaign.js';
import type {Intent} from './rules.js';
export const campaignCommands=['campaign_start','campaign_choose','campaign_pause','campaign_resume','campaign_switch','campaign_continue','campaign_drive','campaign_phone','campaign_review','campaign_portfolio','campaign_compare','campaign_queue','campaign_publish','campaign_withdraw'] as const satisfies readonly Intent['kind'][];
export function capabilities(){return {api:1,campaignVersion:CAMPAIGN_VERSION,campaignMissions:[...missionOrder],campaignCommands:[...campaignCommands]};}
