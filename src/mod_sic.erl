%%%----------------------------------------------------------------------
%%% File    : mod_sic.erl
%%% Author  : Karim Gemayel <karim.gemayel@process-one.net>
%%% Purpose : XEP-0279 Server IP Check
%%% Created : 6 Mar 2010 by Karim Gemayel <karim.gemayel@process-one.net>
%%%
%%%
%%% ejabberd, Copyright (C) 2002-2010   ProcessOne
%%%
%%% This program is free software; you can redistribute it and/or
%%% modify it under the terms of the GNU General Public License as
%%% published by the Free Software Foundation; either version 2 of the
%%% License, or (at your option) any later version.
%%%
%%% This program is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
%%% General Public License for more details.
%%%
%%% You should have received a copy of the GNU General Public License
%%% along with this program; if not, write to the Free Software
%%% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
%%% 02111-1307 USA
%%%
%%%----------------------------------------------------------------------

-module(mod_sic).
-author('karim.gemayel@process-one.net').

-behaviour(gen_mod).

-export([start/2,
	 stop/1,
	 process_local_iq/3,
	 process_sm_iq/3]).

-include_lib("exmpp/include/exmpp.hrl").
-include_lib("exmpp/include/internal/exmpp_xmpp.hrl").
-include("ejabberd.hrl").

start(Host, Opts) ->
    HostB = list_to_binary(Host),
    IQDisc = gen_mod:get_opt(iqdisc, Opts, one_queue),
    mod_disco:register_feature(Host, ?NS_SIC_0_s),
    gen_iq_handler:add_iq_handler(ejabberd_local, HostB, ?NS_SIC_0_s,
				  ?MODULE, process_local_iq, IQDisc),
    gen_iq_handler:add_iq_handler(ejabberd_sm, HostB, ?NS_SIC_0_s,
				  ?MODULE, process_sm_iq, IQDisc).

stop(Host) ->
    HostB = list_to_binary(Host),
    mod_disco:unregister_feature(Host, ?NS_SIC_0_s),
    gen_iq_handler:remove_iq_handler(ejabberd_local, HostB, ?NS_SIC_0_s),
    gen_iq_handler:remove_iq_handler(ejabberd_sm, HostB, ?NS_SIC_0_s).


process_local_iq(From, _To, #iq{type = 'get'} = IQ) ->
    get_ip(From, IQ);

process_local_iq(_From, _To, #iq{type = 'set'} = IQ) ->
    exmpp_iq:error(IQ, 'not-allowed');

process_local_iq(_From, _To, #iq{} = IQ) ->
    exmpp_iq:error(IQ, 'unexpected-request').


process_sm_iq(
  #jid{prep_node = Node, prep_domain = Domain} = From,
  #jid{prep_node = Node, prep_domain = Domain} = _To,
  #iq{type = 'get'} = IQ) ->
    get_ip(From, IQ);

process_sm_iq(_From, _To, #iq{type = 'get'} = IQ) ->
    exmpp_iq:error(IQ, 'forbidden');

process_sm_iq(_From, _To, #iq{type = 'set'} = IQ) ->
    exmpp_iq:error(IQ, 'not-allowed');

process_sm_iq(_From, _To, #iq{} = IQ) ->
    exmpp_iq:error(IQ, 'unexpected-request').

get_ip(From, IQ) ->
    case ejabberd_sm:get_user_ip(From) of
	{IP, _} when is_tuple(IP) ->
	    exmpp_iq:result(IQ,
			    #xmlel{
			      name = 'ip',
			      ns = ?NS_SIC_0_s,
			      children = [?XMLCDATA(list_to_binary(
						      inet_parse:ntoa(IP)))]
			     });
	_ ->
	    exmpp_iq:error(IQ, 'internal-server-error')
    end.
